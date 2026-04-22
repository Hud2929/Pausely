#!/bin/bash

# Pausely Mission Control Deployment Script
# Deploys the admin dashboard to Vercel/Netlify

echo "🚀 Pausely Mission Control Deployment"
echo "======================================"

# Check for required files
if [ ! -f "index.html" ] || [ ! -f "app.js" ] || [ ! -f "styles.css" ]; then
    echo "❌ Error: Required files not found (index.html, app.js, styles.css)"
    exit 1
fi

# Update Supabase credentials
echo ""
echo "⚙️ Configuration"
echo "----------------"
read -p "Enter your Supabase URL: " supabase_url
read -p "Enter your Supabase Anon Key: " supabase_key

# Replace placeholders in app.js
sed -i '' "s|YOUR_SUPABASE_URL|$supabase_url|g" app.js
sed -i '' "s|YOUR_SUPABASE_SERVICE_KEY|$supabase_key|g" app.js

echo ""
echo "📦 Building..."

# Create dist folder
mkdir -p dist
cp index.html dist/
cp app.js dist/
cp styles.css dist/

# Option 1: Vercel deployment
if command -v vercel &> /dev/null; then
    echo ""
    echo "☁️ Deploying to Vercel..."
    cd dist
    vercel --prod
    cd ..
fi

# Option 2: Netlify deployment  
if command -v netlify &> /dev/null; then
    echo ""
    echo "☁️ Deploying to Netlify..."
    cd dist
    netlify deploy --prod
    cd ..
fi

echo ""
echo "✅ Deployment Complete!"
echo ""
echo "🌐 Your Mission Control is live!"
echo "📊 Access your dashboard at the deployed URL"
echo ""
echo "🔐 Security Setup:"
echo "1. Run the SQL in supabase-setup.sql"
echo "2. Set your account as admin:"
echo "   UPDATE profiles SET is_admin = TRUE WHERE email = 'your-email';"
