# Pausely Supabase Setup Guide

This guide will help you set up the required tables in your Supabase project.

## Prerequisites

1. Supabase account (https://supabase.com)
2. A Supabase project created
3. Your Supabase URL and Anonymous Key

## Current Configuration

Your app is already configured with these credentials (in `SupabaseManager.swift`):
- **URL**: `https://ddaotwyaowspwspyddzs.supabase.co`
- **Anon Key**: `sb_publishable_lZhseeKOOHcA_VGHtDZYKQ_qvQCxWJz`

## Step-by-Step Setup

### Step 1: Open Supabase SQL Editor

1. Go to https://app.supabase.com
2. Select your project
3. Click on "SQL Editor" in the left sidebar
4. Click "New Query"

### Step 2: Run the Schema Migration

1. Open the file `supabase_schema.sql` in this project
2. Copy all the SQL content
3. Paste it into the Supabase SQL Editor
4. Click "Run"

### Step 3: Verify Tables Created

After running the SQL, you should see these tables in your Database:

1. **subscriptions** - Stores user subscription data
2. **referral_codes** - Stores referral program codes
3. **referral_conversions** - Tracks referral conversions
4. **user_profiles** - Extended user profile data

### Step 4: Test the Connection

Run the following test query in SQL Editor:

```sql
-- Test if tables exist
SELECT 
    table_name 
FROM 
    information_schema.tables 
WHERE 
    table_schema = 'public' 
    AND table_name IN ('subscriptions', 'referral_codes', 'referral_conversions', 'user_profiles');
```

You should see all 4 tables listed.

## Required Database Tables

### 1. Subscriptions Table
Stores all user subscription data.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| user_id | UUID | Foreign key to auth.users |
| name | TEXT | Subscription name (e.g., "Netflix") |
| amount | DECIMAL | Monthly/yearly cost |
| currency | TEXT | Currency code (USD, EUR, etc.) |
| billing_frequency | TEXT | monthly, yearly, weekly |
| category | TEXT | Entertainment, Productivity, etc. |
| status | TEXT | active, paused, cancelled |
| is_detected | BOOLEAN | Auto-detected by scanner |
| next_billing_date | TIMESTAMPTZ | When next payment is due |

### 2. Referral Codes Table
Stores referral codes for the referral program.

| Column | Type | Description |
|--------|------|-------------|
| code | TEXT | Primary key (e.g., "PAUSELY-ABC123") |
| referrer_user_id | UUID | Who owns this code |
| conversions | INTEGER | How many people used it |
| is_eligible_for_free_pro | BOOLEAN | 3+ referrals = free Pro |

### 3. Referral Conversions Table
Tracks who signed up using a referral code.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| referrer_code | TEXT | Which code was used |
| referred_user_id | UUID | Who signed up |
| status | TEXT | pending, converted, expired |

### 4. User Profiles Table (Optional)
Extended user data beyond auth.users.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Same as auth.users id |
| first_name | TEXT | User's first name |
| last_name | TEXT | User's last name |
| subscription_tier | TEXT | free, premium, premium_annual |
| is_premium | BOOLEAN | Current premium status |

## Security Features

All tables have **Row Level Security (RLS)** enabled:

- Users can only see/edit their OWN data
- Referral codes are readable by anyone (for validation)
- Subscription data is private to each user

## Realtime Updates

The subscriptions table is configured for realtime updates, meaning:
- Changes sync instantly across devices
- Live updates when subscriptions are added/modified

## Testing the Integration

After setting up the tables, test the app:

1. Sign up for a new account in the app
2. Add a subscription
3. Check Supabase Table Editor - you should see the data
4. The data should persist across app restarts

## Troubleshooting

### "Table not found" error
- Make sure you ran the SQL migration
- Check that tables exist in Table Editor

### "Permission denied" error
- RLS policies might not be set correctly
- Re-run the SQL migration

### "No such module 'Supabase'" build error
- Build should be working now with the modular imports (Auth, PostgREST, etc.)

## Next Steps

1. ✅ Run the SQL migration in Supabase
2. ✅ Verify tables are created
3. ✅ Test adding a subscription in the app
4. ✅ Check data appears in Supabase Table Editor

## Support

If you encounter issues:
1. Check Supabase logs in Dashboard > Logs
2. Verify RLS policies are correctly applied
3. Ensure your anon key matches what's in Supabase Settings > API
