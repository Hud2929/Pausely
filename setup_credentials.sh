#!/bin/bash
echo "🔐 Pausely Credential Setup"
read -p "Supabase URL: " SUPABASE_URL
read -p "Supabase Anon Key: " SUPABASE_ANON_KEY
read -p "Supabase Service Role Key: " SUPABASE_SERVICE_ROLE_KEY
read -p "Lemon Squeezy API Key: " LEMON_SQUEEZY_API_KEY
read -p "Lemon Squeezy Store ID: " LEMON_SQUEEZY_STORE_ID
read -p "Lemon Squeezy Webhook Secret: " LEMON_SQUEEZY_WEBHOOK_SECRET
echo "✅ Credentials configured"
