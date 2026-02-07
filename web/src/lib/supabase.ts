import { createClient } from '@supabase/supabase-js'
import type { User, Session } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || ''
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || ''

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  }
})

// Rate limiting with exponential backoff
class RateLimiter {
  private attempts: Map<string, number[]> = new Map()
  private readonly maxAttempts = 5
  private readonly windowMs = 60000 // 1 minute
  private readonly baseDelay = 2000 // 2 seconds

  canProceed(key: string): { allowed: boolean; waitMs: number } {
    const now = Date.now()
    const attempts = this.attempts.get(key) || []
    
    // Clean old attempts
    const recentAttempts = attempts.filter(time => now - time < this.windowMs)
    
    if (recentAttempts.length >= this.maxAttempts) {
      const oldestAttempt = recentAttempts[0]
      const waitMs = this.windowMs - (now - oldestAttempt)
      return { allowed: false, waitMs }
    }
    
    return { allowed: true, waitMs: 0 }
  }

  recordAttempt(key: string): void {
    const now = Date.now()
    const attempts = this.attempts.get(key) || []
    attempts.push(now)
    this.attempts.set(key, attempts)
  }

  getDelayForAttempt(key: string): number {
    const attempts = this.attempts.get(key) || []
    const attemptCount = attempts.length
    // Exponential backoff: 2s, 4s, 8s, 16s, 32s
    return Math.min(this.baseDelay * Math.pow(2, attemptCount), 32000)
  }

  reset(key: string): void {
    this.attempts.delete(key)
  }
}

export const authRateLimiter = new RateLimiter()

// Enhanced auth functions with rate limiting
export async function signUpWithEmail(email: string, password: string, fullName?: string) {
  const rateLimitKey = `signup:${email.toLowerCase()}`
  const { allowed, waitMs } = authRateLimiter.canProceed(rateLimitKey)
  
  if (!allowed) {
    return {
      error: new Error(`Rate limit exceeded. Please try again in ${Math.ceil(waitMs / 1000)} seconds.`),
      data: null
    }
  }

  authRateLimiter.recordAttempt(rateLimitKey)

  try {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name: fullName || email.split('@')[0]
        },
        // Auto-confirm email for smoother UX
        emailRedirectTo: `${window.location.origin}/auth/callback`
      }
    })

    if (error) {
      // Handle specific Supabase errors
      if (error.message.includes('rate limit') || error.status === 429) {
        return {
          error: new Error('Too many signup attempts. Please wait a minute and try again.'),
          data: null
        }
      }
      if (error.message.includes('already registered') || error.message.includes('already exists')) {
        return {
          error: new Error('This email is already registered. Please sign in instead.'),
          data: null
        }
      }
      return { error, data: null }
    }

    // Auto sign in after successful signup (email confirmation bypass)
    if (data.user) {
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email,
        password
      })
      
      if (!signInError) {
        authRateLimiter.reset(rateLimitKey)
        return { error: null, data }
      }
    }

    return { error: null, data }
  } catch (err: any) {
    return {
      error: new Error(err?.message || 'An unexpected error occurred. Please try again.'),
      data: null
    }
  }
}

export async function signInWithEmail(email: string, password: string) {
  const rateLimitKey = `signin:${email.toLowerCase()}`
  const { allowed, waitMs } = authRateLimiter.canProceed(rateLimitKey)
  
  if (!allowed) {
    return {
      error: new Error(`Too many login attempts. Please try again in ${Math.ceil(waitMs / 1000)} seconds.`),
      data: null
    }
  }

  authRateLimiter.recordAttempt(rateLimitKey)

  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    })

    if (error) {
      if (error.message.includes('rate limit') || error.status === 429) {
        return {
          error: new Error('Too many login attempts. Please wait a minute and try again.'),
          data: null
        }
      }
      if (error.message.includes('Invalid login')) {
        return {
          error: new Error('Invalid email or password. Please check your credentials.'),
          data: null
        }
      }
      if (error.message.includes('Email not confirmed')) {
        return {
          error: new Error('Please check your email to confirm your account.'),
          data: null
        }
      }
      return { error, data: null }
    }

    authRateLimiter.reset(rateLimitKey)
    return { error: null, data }
  } catch (err: any) {
    return {
      error: new Error(err?.message || 'An unexpected error occurred. Please try again.'),
      data: null
    }
  }
}

export async function signOut() {
  try {
    const { error } = await supabase.auth.signOut()
    return { error }
  } catch (err: any) {
    return { error: new Error(err?.message || 'Failed to sign out') }
  }
}

export async function getCurrentUser(): Promise<User | null> {
  const { data: { user } } = await supabase.auth.getUser()
  return user
}

export async function getCurrentSession(): Promise<Session | null> {
  const { data: { session } } = await supabase.auth.getSession()
  return session
}

export function onAuthStateChange(callback: (event: string, session: Session | null) => void) {
  return supabase.auth.onAuthStateChange(callback)
}

// Password reset
export async function resetPassword(email: string) {
  const rateLimitKey = `reset:${email.toLowerCase()}`
  const { allowed, waitMs } = authRateLimiter.canProceed(rateLimitKey)
  
  if (!allowed) {
    return {
      error: new Error(`Too many attempts. Please try again in ${Math.ceil(waitMs / 1000)} seconds.`),
      data: null
    }
  }

  authRateLimiter.recordAttempt(rateLimitKey)

  const { data, error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${window.location.origin}/auth/reset-password`
  })

  return { data, error }
}

// Update password
export async function updatePassword(newPassword: string) {
  const { data, error } = await supabase.auth.updateUser({
    password: newPassword
  })
  return { data, error }
}
