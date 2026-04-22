# Database Setup Required

## ⚠️ Database Not Set Up

Your Pausely app is trying to save subscriptions, but the database table doesn't exist yet.

---

## How to Fix This

### Step 1: Open Supabase Dashboard
1. Go to [supabase.com](https://supabase.com) and sign in to your account
2. Select your Pausely project from the dashboard

### Step 2: Open SQL Editor
1. Click **"SQL Editor"** in the left sidebar
2. Click **"New Query"** button

### Step 3: Run the Setup Script
1. Open the file `FINAL_SUPABASE_SETUP.sql` from your project folder
2. Copy the entire contents
3. Paste into the SQL Editor
4. Click **"Run"** button

### Step 4: Verify Setup
You should see a success message saying "PAUSELY DATABASE SETUP COMPLETE!"

### Step 5: Return to App
1. Close and reopen the Pausely app
2. Try adding a subscription again

---

## What This Does

The SQL script creates:
- **subscriptions** table - stores all your subscription data
- **referral_codes** table - for the referral program
- **referral_conversions** table - tracks successful referrals
- **user_settings** table - stores your preferences
- **Row Level Security (RLS)** - ensures your data is private and secure
- **Indexes** - makes the app fast and responsive

---

## Alternative: Minimal Setup

If you only need the essentials, run this minimal SQL instead:

```sql
-- Create subscriptions table
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    logo_url TEXT,
    category TEXT,
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT DEFAULT 'USD',
    billing_frequency TEXT DEFAULT 'monthly',
    next_billing_date DATE,
    monthly_usage_minutes INTEGER DEFAULT 0,
    cost_per_hour DECIMAL(10,2),
    roi_score DECIMAL(5,2),
    status TEXT DEFAULT 'active',
    is_detected BOOLEAN DEFAULT false,
    can_pause BOOLEAN DEFAULT true,
    pause_url TEXT,
    paused_until DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can only see their own subscriptions"
    ON subscriptions FOR ALL
    USING (auth.uid() = user_id);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
```

---

## Still Having Issues?

### Check These Common Problems:

**1. Wrong Supabase Project**
- Make sure you're using the same Supabase project that the app is configured to use
- Check `SupabaseManager.swift` for the project URL

**2. Already Ran the SQL?**
- Try restarting the app completely
- The table might already exist but the app needs to reconnect

**3. Authentication Issues**
- Make sure you're signed in to the app
- The database requires an authenticated user

**4. Network Connection**
- Check your internet connection
- Try connecting to a different WiFi network

---

## Need Help?

Contact us at **support@pausely.app**

Include:
- The error message you're seeing
- Steps you've already tried
- Screenshot of your Supabase project dashboard

---

*This setup is required only once per Supabase project. Once complete, all users can save subscriptions normally.*
