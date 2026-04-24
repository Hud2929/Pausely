import { $Database, $Env, OpenApiExtension, PocketUIExtension, teenyHono } from 'teenybase/worker';
import config from '../migrations/config.json';
import { DatabaseSettings } from "teenybase";

export interface Env {
  Bindings: $Env['Bindings'] & {
    PRIMARY_DB: D1Database;
    PRIMARY_R2?: R2Bucket;
  },
  Variables: $Env['Variables']
}

// ============================================================================
// Security Constants
// ============================================================================

const RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000; // 15 minutes
const RATE_LIMIT_MAX_ATTEMPTS = 5;
const MAX_REQUEST_SIZE_BYTES = 1024 * 1024; // 1MB

// Email regex (RFC 5322 compliant subset)
const EMAIL_REGEX = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;

// ============================================================================
// Rate Limiting Helper (uses kv_store table)
// ============================================================================

/**
 * Checks if an IP has exceeded the rate limit for a given action.
 * Uses the kv_store table to track attempts with a sliding window.
 *
 * @param db - The D1 database instance
 * @param ip - Client IP address
 * @param action - Action identifier (e.g., 'auth_login', 'auth_register')
 * @returns null if allowed, or a rejection message if blocked
 */
async function checkRateLimit(
  db: D1Database,
  ip: string,
  action: string
): Promise<string | null> {
  const key = `rate_limit:${ip}:${action}`;
  const now = Date.now();
  const windowStart = now - RATE_LIMIT_WINDOW_MS;

  // Fetch current rate limit entry from kv_store
  const existing = await db
    .prepare("SELECT value FROM kv_store WHERE key = ? AND (expire IS NULL OR expire > datetime('now'))")
    .bind(key)
    .first<{ value: string }>();

  let entry: { attempts: number; windowStart: number } = { attempts: 0, windowStart: now };

  if (existing?.value) {
    try {
      entry = JSON.parse(existing.value);
    } catch {
      entry = { attempts: 0, windowStart: now };
    }
  }

  // Reset if window has expired
  if (entry.windowStart < windowStart) {
    entry = { attempts: 0, windowStart: now };
  }

  // Check limit
  if (entry.attempts >= RATE_LIMIT_MAX_ATTEMPTS) {
    const retryAfter = Math.ceil((entry.windowStart + RATE_LIMIT_WINDOW_MS - now) / 1000);
    return `Rate limit exceeded. Try again in ${retryAfter} seconds.`;
  }

  // Increment attempts
  entry.attempts += 1;

  // Upsert into kv_store with expiration
  const expireIso = new Date(now + RATE_LIMIT_WINDOW_MS).toISOString();
  await db
    .prepare(`
      INSERT INTO kv_store (key, value, expire)
      VALUES (?, ?, ?)
      ON CONFLICT(key) DO UPDATE SET
        value = excluded.value,
        expire = excluded.expire
    `)
    .bind(key, JSON.stringify(entry), expireIso)
    .run();

  return null;
}

/**
 * Extracts the client IP from the Hono context.
 */
function getClientIP(c: any): string {
  // Try common headers, fallback to 'unknown'
  const headers = c.req.raw.headers;
  const forwarded = headers.get('cf-connecting-ip')
    || headers.get('x-forwarded-for')?.split(',')[0]?.trim()
    || headers.get('x-real-ip')
    || 'unknown';
  return forwarded;
}

/**
 * Checks if the request path is an auth-related route that should be rate limited.
 */
function isAuthRoute(path: string): boolean {
  const authPaths = [
    '/api/v1/auth/',
    '/api/v1/users',
    '/api/v1/request-password-reset',
    '/api/v1/confirm-password-reset',
    '/api/v1/verify-email',
    '/api/v1/request-email-verification',
  ];
  return authPaths.some(p => path.startsWith(p));
}

// ============================================================================
// App Setup
// ============================================================================

const app = teenyHono<Env>(async (c)=> {
  const db = new $Database(c, config as unknown as DatabaseSettings, c.env.PRIMARY_DB, c.env.PRIMARY_R2)
  db.extensions.push(new OpenApiExtension(db, true))
  db.extensions.push(new PocketUIExtension(db))

  return db
}, undefined, {
  logger: false,
  cors: true,
})

// ============================================================================
// Security Middleware
// ============================================================================

/**
 * Request size limit middleware.
 * Rejects requests with body larger than MAX_REQUEST_SIZE_BYTES (1MB).
 */
app.use('*', async (c, next) => {
  const contentLength = c.req.raw.headers.get('content-length');
  if (contentLength && parseInt(contentLength, 10) > MAX_REQUEST_SIZE_BYTES) {
    return c.json({ error: 'Request body too large. Maximum size is 1MB.' }, 413);
  }

  // For chunked transfers, we can't pre-check size easily.
  // The body will be parsed downstream; we rely on the content-length header.
  await next();
});

/**
 * Rate limiting middleware for auth routes.
 * Tracks IP + endpoint in kv_store, max 5 attempts per 15 minutes.
 */
app.use('*', async (c, next) => {
  const path = new URL(c.req.url).pathname;

  if (!isAuthRoute(path)) {
    await next();
    return;
  }

  const ip = getClientIP(c);
  const action = path; // Use path as action identifier

  const rateLimitError = await checkRateLimit(c.env.PRIMARY_DB, ip, action);
  if (rateLimitError) {
    return c.json({ error: rateLimitError }, 429);
  }

  await next();
});

/**
 * Input validation middleware for auth routes.
 * Validates email format and password minimum length on registration.
 */
app.use('/api/v1/users', async (c, next) => {
  if (c.req.method !== 'POST') {
    await next();
    return;
  }

  try {
    const body = await c.req.json();

    // Email validation
    if (body.email && !EMAIL_REGEX.test(body.email)) {
      return c.json({ error: 'Invalid email format.' }, 400);
    }

    // Password minimum length validation
    if (body.password && body.password.length < 8) {
      return c.json({ error: 'Password must be at least 8 characters long.' }, 400);
    }

    await next();
  } catch {
    // If body parsing fails, let downstream handle it
    await next();
  }
});

/**
 * Input validation middleware for password reset.
 */
app.use('/api/v1/confirm-password-reset', async (c, next) => {
  if (c.req.method !== 'POST') {
    await next();
    return;
  }

  try {
    const body = await c.req.json();

    if (body.password && body.password.length < 8) {
      return c.json({ error: 'Password must be at least 8 characters long.' }, 400);
    }

    await next();
  } catch {
    await next();
  }
});

// ============================================================================
// Routes
// ============================================================================

app.get('/', (c)=>{
  return c.json({message: 'Hello Hono'})
})

export default app
