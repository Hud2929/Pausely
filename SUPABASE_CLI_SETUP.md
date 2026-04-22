# Supabase CLI Setup & Migration

## Step 1: Get Your Access Token

1. Go to https://app.supabase.com/account/tokens
2. Click "Generate New Token"
3. Give it a name like "Pausely CLI"
4. Copy the token

## Step 2: Login to Supabase CLI

Run this command in your terminal:

```bash
export PATH="$HOME/.local/bin:$PATH"
supabase login
```

When prompted, paste your access token.

## Step 3: Link Your Project

```bash
cd ~/Desktop/Pausely
export PATH="$HOME/.local/bin:$PATH"
supabase link --project-ref ddaotwyaowspwspyddzs
```

## Step 4: Push Migrations

```bash
export PATH="$HOME/.local/bin:$PATH"
supabase db push
```

This will create all the tables in your remote Supabase project!

## Alternative: Manual SQL Execution

If you prefer not to use the CLI, you can copy the migration file contents and run it manually:

1. Open `supabase/migrations/20260304172111_create_pausely_tables.sql`
2. Copy all the SQL
3. Go to https://app.supabase.com/project/ddaotwyaowspwspyddzs/sql-editor
4. Paste and run the SQL

## Migration File Created

✅ `supabase/migrations/20260304172111_create_pausely_tables.sql`

This migration creates:
- `subscriptions` table with RLS policies
- `referral_codes` table with RLS policies
- `referral_conversions` table with RLS policies
- `user_profiles` table with RLS policies
- Triggers for `updated_at` columns
- Realtime publication for live updates
