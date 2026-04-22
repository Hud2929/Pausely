#!/bin/bash

echo "🚀 Pausely Referral System Quick Setup"
echo "========================================"
echo ""

echo "Step 1: Checking Prerequisites..."
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Installing..."
    npm install -g supabase
fi

echo "✅ Supabase CLI found"
echo ""

echo "Step 2: Login to Supabase..."
supabase login

echo ""
echo "Step 3: Link your project..."
echo "Enter your Supabase project ref (from Settings > General):"
read PROJECT_REF

supabase link --project-ref $PROJECT_REF

echo ""
echo "Step 4: Deploy webhook function..."
supabase functions deploy lemon-squeezy-webhook

echo ""
echo "✅ Setup Complete!"
echo ""
echo "Next steps:"
echo "1. Create REFERRAL30 discount in LemonSqueezy"
echo "2. Add webhook URL to LemonSqueezy"
echo "3. Test with a referral code"
echo ""
echo "📖 Full guide: SETUP_REFERRAL_SYSTEM.md"
