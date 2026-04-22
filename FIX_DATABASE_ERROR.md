# Fix: "Could not find the table public subscriptions" Error

## Problem
When adding a subscription, you see this error:
```
could not find the table public subscriptions in the schema cache
```

This means the **subscriptions table doesn't exist** in your Supabase database yet.

---

## Solution

### Step 1: Open Supabase SQL Editor
1. Go to [supabase.com](https://supabase.com) and sign in
2. Select your Pausely project
3. Click **"SQL Editor"** in the left sidebar
4. Click **"New Query"**

### Step 2: Run the Setup SQL
Copy and paste the entire contents of `FINAL_SUPABASE_SETUP.sql` (in this folder) into the SQL Editor, then click **"Run"**.

> **Note:** Use `FINAL_SUPABASE_SETUP.sql` which includes all tables, RLS policies, and functions needed for the complete app.

Or run this minimal version:

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

### Step 3: Verify
You should see a success message. The table is now created.

### Step 4: Return to App
The error should be gone. You can now add subscriptions normally.

> **Tip:** You may need to close and reopen the app if it was already running.

---

## What the SQL Does

1. **Creates the subscriptions table** with all necessary columns
2. **Enables Row Level Security (RLS)** - ensures users can only access their own data
3. **Creates policies** - defines who can read/write data
4. **Creates indexes** - makes queries faster

---

## Still Getting Errors?

### Check Authentication
Make sure you're signed in. The app needs an authenticated user to save subscriptions.

### Check Supabase URL/Key
In `SupabaseManager.swift`, verify:
- `supabaseURL` matches your project URL
- `supabaseKey` is correct

### Check RLS Policies
In Supabase Dashboard:
1. Go to **Table Editor** → **subscriptions**
2. Click **"Policies"** tab
3. Verify policies exist (you should see the one created above)

---

## Need Help?

If you're still stuck, check the Supabase logs:
1. In Supabase Dashboard, click **"Logs"** in the sidebar
2. Look for any errors related to the subscriptions table
