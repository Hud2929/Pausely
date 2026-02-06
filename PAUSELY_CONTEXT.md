# PAUSELY PROJECT CONTEXT

## 👤 ABOUT ME (Hudson)
- Name: Hudson Kim
- Email: hudwkim@gmail.com  
- Phone: +1 416-936-3534
- Telegram ID: 6538910985
- I'm under 18 (can't get Apple Developer $99 account yet)

## 📱 PROJECT: PAUSELY
Subscription optimization app that helps users get MORE value while spending LESS.

### Key Features:
- Tracks subscriptions from bank accounts
- Shows cost-per-hour instead of monthly fees
- Discovers free perks (credit cards, employer, library)
- Pause-first philosophy instead of cancel

### Domain:
- pausely.pro (already purchased)

### Tech Stack:
- Frontend: React + TypeScript + Tailwind + Vite (web app)
- iOS: SwiftUI (for later when I get Apple Dev)
- Backend: Supabase (PostgreSQL + Auth)
- Hosting: Vercel

## ✅ WHAT'S BEEN BUILT

### 1. Web App (Ready to Deploy)
Location: `/home/hudson/.openclaw/workspace/pausely/web/`

Features:
- Onboarding flow (4 screens)
- Sign up / Sign in with email
- Dashboard showing total spend
- Add/view subscriptions
- Free perks discovery page
- Profile page
- Mobile-responsive design

### 2. iOS App (Ready for Future)
Location: `/home/hudson/.openclaw/workspace/pausely/ios/Pausely/`

Features:
- Full SwiftUI app
- Same features as web
- App Store ready structure

### 3. Database Schema
Location: `/home/hudson/.openclaw/workspace/pausely/backend/supabase/migrations/001_initial_schema.sql`

Tables created:
- profiles (users)
- subscriptions
- bank_connections
- user_perks
- perk_opportunities
- pause_history
- screen_time
- subscription_catalog

### 4. Documentation
- README.md
- SETUP_CHECKLIST.md
- DEPLOY.md
- EXPLAINED.md
- QUICKSTART.md

## 🔧 SUPABASE CREDENTIALS
- Project URL: https://vovwtweemrjoxkiwpehu.supabase.co
- Anon Key: sb_publishable_WP-QP_k_ipqIotaWu5VqMw_NdLvqI0z

SQL migration has been run in Supabase (tables exist).

## 📁 GITHUB REPO
- URL: https://github.com/Hud2929/Pausely
- Status: Empty (code is on VPS, needs to be pushed)

## 🚀 CURRENT STATUS

### What's Working:
- ✅ All code is written and built
- ✅ Supabase database set up
- ✅ Web app compiled and ready
- ✅ Environment variables configured
- ✅ Git commits made locally

### What Needs to Happen:
⏳ Push code from VPS to GitHub
⏳ Deploy to Vercel
⏳ Connect pausely.pro domain

## 📂 FILE LOCATIONS

All code is on the VPS at:
```
/home/hudson/.openclaw/workspace/pausely/
├── ios/Pausely/              # iOS Swift app
├── web/                      # React web app
│   ├── src/components/       # Dashboard, Subscriptions, Perks, Profile
│   ├── src/lib/supabase.ts   # Supabase client
│   ├── .env                  # Has Supabase credentials
│   └── dist/                 # Built files ready to deploy
├── backend/supabase/migrations/  # Database schema
└── docs/                     # Documentation
```

## 🎯 NEXT STEPS

1. Push code to GitHub (from VPS to Hud2929/Pausely)
2. Import repo to Vercel
3. Configure build settings:
   - Framework: Vite
   - Build Command: `cd web && npm run build`
   - Output Directory: `web/dist`
4. Add environment variables (already in web/.env)
5. Deploy
6. Connect pausely.pro domain

## 💰 COSTS
- Domain (pausely.pro): ~$10 ✅
- Supabase: Free tier ✅
- Vercel: Free tier ✅
- Apple Developer: $99/year ⏳ (waiting until I'm 18)

## 📝 NOTES
- Web app is mobile-first design (works great on phones)
- iOS app is built but can't test on device without Apple Dev account
- Database has RLS (Row Level Security) enabled
- All code is committed locally, just needs push to origin
