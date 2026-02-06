# Pausely

**Subscription optimization that maximizes value, not just cancellations.**

Pausely is an app that connects to your bank accounts to identify every recurring charge, then calculates a personal ROI score for each subscription based on your actual usage. Instead of seeing "Netflix - $15.99," you see "Netflix - $8.00 per hour this month" — revealing which subscriptions are actually worth keeping.

## 🚀 Quick Start (No Apple Dev Needed!)

Want to test on your phone **right now** without paying $99 for Apple Developer? Use the **web version**!

### Test on Your Phone (2 minutes)

```bash
cd web
npm install
npm run dev -- --host
```

Then open the shown IP address on your phone's browser (same WiFi).

### Deploy for Free

1. **Fork/clone this repo** to your GitHub: https://github.com/Hud2929/Pausely
2. **Connect to Supabase** (see below)
3. **Deploy to Vercel/Netlify** (free)
4. **Point your domain** pausely.pro to it

See [DEPLOY.md](DEPLOY.md) for detailed instructions.

## Key Features

- **True Cost Visibility**: Cost-per-hour calculations based on Screen Time data
- **Free Perk Unlocking**: Discover $50-100/month in free alternatives (credit card perks, employer benefits, library access)
- **Pause-First Philosophy**: Pause subscriptions instead of canceling (many services hide this feature)
- **Smart Detection**: Automatically identifies recurring charges from bank transactions

## Project Structure

```
pausely/
├── ios/                          # iOS Swift app (for App Store later)
│   └── Pausely/
│       ├── Models/               # Data models
│       ├── Views/                # SwiftUI views
│       ├── ViewModels/           # State management
│       ├── Services/             # Supabase integration
│       └── Utils/                # Helpers
├── web/                          # React web app (test on phone NOW)
│   ├── src/
│   │   ├── components/           # Dashboard, Subscriptions, Perks
│   │   └── lib/                  # Supabase client
│   └── .env.example              # Config template
├── backend/
│   └── supabase/
│       └── migrations/           # Database schema
└── docs/                         # Documentation
```

## Supabase Setup (5 minutes)

1. Create account at https://supabase.com
2. Create new project
3. Go to SQL Editor → New query
4. Copy/paste: `backend/supabase/migrations/001_initial_schema.sql`
5. Run the query
6. Go to Project Settings → API
7. Copy `Project URL` and `anon public` key
8. Create `web/.env`:
```
VITE_SUPABASE_URL=https://your-project-id.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
```

## Web App Quick Start

```bash
cd web
npm install
npm run dev          # Local dev
npm run build        # Production build
```

## iOS App (Requires Apple Developer)

```bash
cd ios/Pausely
# Open in Xcode
# Update SupabaseManager.swift with your credentials
# Build and run
```

## What's Built

### ✅ Web App (Ready Now)
- Dashboard with spend overview
- Subscription list with add/edit
- Free perks discovery page
- User profile
- Authentication (email/password)
- Mobile-first responsive design

### ✅ iOS App (Ready when you get Apple Dev)
- Full SwiftUI app
- Same features as web
- Native iOS look/feel
- App Store ready structure

### ✅ Backend
- Complete Supabase schema
- Row Level Security
- Auto-calculated fields
- Ready for Plaid integration

## Cost Breakdown

| Item | Cost | Status |
|------|------|--------|
| Domain (pausely.pro) | ~$10 | ✅ Done |
| Web Hosting | Free | ✅ Via Vercel/Netlify |
| Supabase | Free tier | ✅ Up to 500MB |
| Apple Developer | $99/year | ⏳ Optional (for iOS) |
| **Total to start** | **$10** | |

## Next Steps

1. ✅ Set up Supabase (5 min)
2. ✅ Deploy web app (5 min)
3. ✅ Test on your phone!
4. ⏳ Add real bank integration (Plaid)
5. ⏳ Build free perk database
6. ⏳ iOS App Store (when ready)

## Environment Variables

Create `web/.env`:
```
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_anon_key
```

## Tech Stack

- **Frontend**: React + TypeScript + Tailwind CSS + Vite
- **iOS**: SwiftUI (for future App Store)
- **Backend**: Supabase (PostgreSQL + Auth + Realtime)
- **Banking**: Plaid API (future)
- **Hosting**: Vercel/Netlify (free)

## Database Schema

### Tables
- `profiles` - User profiles
- `subscriptions` - User's tracked subscriptions
- `bank_connections` - Connected bank accounts
- `user_perks` - Free perks the user has access to
- `perk_opportunities` - Subscription/perk match opportunities
- `pause_history` - Track pause/resume history
- `screen_time` - Usage data from device
- `subscription_catalog` - Known subscription services

## License

Private - All rights reserved

## Contact

Hudson Kim - hudson@pausely.pro
