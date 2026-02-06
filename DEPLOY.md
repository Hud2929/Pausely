# Deploying Pausely Web App

## Option 1: Deploy to Vercel (Easiest - Free)

1. Go to https://vercel.com and sign up with GitHub
2. Import your repo: https://github.com/Hud2929/Pausely
3. Set build settings:
   - Framework: Vite
   - Build command: `cd web && npm run build`
   - Output directory: `web/dist`
4. Add environment variables (from your Supabase project):
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
5. Deploy!

## Option 2: Deploy to Netlify (Free)

1. Go to https://netlify.com
2. Drag & drop the `web/dist` folder after building
3. Or connect your GitHub repo for auto-deploys

## Option 3: Use Your Domain (pausely.pro)

You'll need a hosting service. Options:
- **Cloudflare Pages**: Free, fast, easy
- **GitHub Pages**: Free, but limited
- **Vercel/Netlify**: Free custom domains

## Building Locally

```bash
cd /home/hudson/.openclaw/workspace/pausely/web
npm install
npm run build
```

The `dist/` folder will contain the built files ready to deploy.

## Connect to YOUR Supabase

1. Go to https://supabase.com → Your Project → Settings → API
2. Copy the `Project URL` and `anon public` key
3. Create `web/.env` file:
```
VITE_SUPABASE_URL=https://your-project-id.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
```
4. Rebuild: `npm run build`

## Test on Your Phone (Before Deploy)

```bash
cd web
npm run dev -- --host
```

This shows your local IP. Open that on your phone's browser (same WiFi).

## Next Steps

1. Set up Supabase project (5 min)
2. Run the SQL migration from `backend/supabase/migrations/001_initial_schema.sql`
3. Deploy web app
4. Test on your phone!
