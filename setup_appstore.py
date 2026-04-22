#!/usr/bin/env python3
"""
App Store Connect Product Setup Helper
This script helps prepare metadata for App Store Connect subscription products.

NOTE: This script does NOT create products directly (requires Apple authentication).
It generates the proper configuration files and provides step-by-step instructions.

Usage:
    python3 setup_appstore.py
"""

import json
import sys
from datetime import datetime

# Product configuration matching the app's StoreKitConfig.swift
PRODUCTS = {
    "subscription_group": {
        "reference_name": "Pausely Pro Subscriptions",
        "display_name": "Pausely Pro",
        "group_id": "com.pausely.premium"
    },
    "products": [
        {
            "name": "Monthly Pro",
            "product_id": "com.pausely.premium.monthly",
            "reference_name": "Monthly Pro",
            "duration": "1 Month",
            "price_usd": 7.99,
            "tier": 60,
            "group_level": 2,
            "trial": "1 Week Free",
            "features": [
                "Unlimited subscription tracking",
                "Smart pause functionality",
                "Cost per hour analysis",
                "AI financial advisor",
                "Subscription health score"
            ]
        },
        {
            "name": "Annual Pro",
            "product_id": "com.pausely.premium.annual",
            "reference_name": "Annual Pro",
            "duration": "1 Year",
            "price_usd": 69.99,
            "tier": 85,
            "group_level": 1,
            "trial": "1 Week Free",
            "savings": "34%",
            "features": [
                "All Monthly Pro features",
                "Save 27% vs monthly",
                "Priority support"
            ]
        }
    ]
}

def print_header(text):
    """Print formatted header"""
    print("\n" + "="*70)
    print(f"  {text}")
    print("="*70 + "\n")

def print_step(number, title):
    """Print step header"""
    print(f"\n{'─'*70}")
    print(f"STEP {number}: {title}")
    print(f"{'─'*70}")

def generate_appstore_xml():
    """Generate XML for App Store Connect API (if using automated upload)"""
    xml = '''<?xml version="1.0" encoding="UTF-8"?>
<subscription_group>
    <reference_name>Pausely Pro Subscriptions</reference_name>
    <subscriptions>
        <subscription>
            <product_id>com.pausely.premium.monthly</product_id>
            <reference_name>Monthly Pro</reference_name>
            <duration>1 Month</duration>
            <price_tier>60</price_tier>
            <group_level>2</group_level>
            <introductory_offer>
                <type>free_trial</type>
                <duration>1 Week</duration>
            </introductory_offer>
        </subscription>
        <subscription>
            <product_id>com.pausely.premium.annual</product_id>
            <reference_name>Annual Pro</reference_name>
            <duration>1 Year</duration>
            <price_tier>85</price_tier>
            <group_level>1</group_level>
            <introductory_offer>
                <type>free_trial</type>
                <duration>1 Week</duration>
            </introductory_offer>
        </subscription>
    </subscriptions>
</subscription_group>'''
    return xml

def generate_markdown_guide():
    """Generate a quick reference guide"""
    guide = """# Quick Setup Guide

## Login
1. Go to https://appstoreconnect.apple.com
2. Sign in with Apple Developer account

## Navigate
1. Click "My Apps"
2. Select "Pausely" (or create new app with bundle ID: com.pausely.app.Pausely)
3. Click "Subscriptions" in left sidebar

## Create Group
Click "Create Subscription Group"
- Reference Name: `Pausely Pro Subscriptions`
- Display Name: `Pausely Pro`

## Create Monthly Product
Click "Create Subscription"
1. **Product Information**
   - Reference Name: `Monthly Pro`
   - Product ID: `com.pausely.premium.monthly` ⚠️ EXACT MATCH REQUIRED
   - Display Name: `Pausely Pro Monthly`
   - Description: `Unlimited subscriptions + AI features`

2. **Subscription Details**
   - Duration: `1 Month`
   - Group: `Pausely Pro Subscriptions`
   - Group Level: `2`

3. **Pricing**
   - Price: `$7.99` (Tier 62)
   - Select all territories

4. **Introductory Offer**
   - Type: `Free Trial`
   - Duration: `1 Week`
   - Click "Save"

## Create Annual Product
Click "Create Subscription"
1. **Product Information**
   - Reference Name: `Annual Pro`
   - Product ID: `com.pausely.premium.annual` ⚠️ EXACT MATCH REQUIRED
   - Display Name: `Pausely Pro Annual`
   - Description: `Save 27% with annual billing`

2. **Subscription Details**
   - Duration: `1 Year`
   - Group: `Pausely Pro Subscriptions`
   - Group Level: `1`

3. **Pricing**
   - Price: `$69.99` (Tier 89)
   - Select all territories

4. **Introductory Offer**
   - Type: `Free Trial`
   - Duration: `1 Week`
   - Click "Save"

## Submit for Review
1. Both products should show "Ready to Submit"
2. Add review screenshots
3. Submit with app binary
"""
    return guide

def print_verification_checklist():
    """Print verification checklist"""
    print_step("VERIFICATION", "Before Submitting")
    
    checklist = [
        ("Apple Developer Program", "Active membership ($99/year)"),
        ("Paid Apps Agreement", "Signed in Agreements section"),
        ("Tax Forms", "W-9 (US) or W-8BEN (International)"),
        ("Banking Info", "Added for payouts"),
        ("App Record", "Created with bundle ID com.pausely.app.Pausely"),
        ("Subscription Group", "Pausely Pro Subscriptions"),
        ("Monthly Product", "com.pausely.premium.monthly - $7.99"),
        ("Annual Product", "com.pausely.premium.annual - $69.99"),
        ("Trial Offers", "Both products have 1-week free trial"),
        ("Review Screenshots", "Added to both products"),
        ("Sandbox Testers", "At least 1 created for testing"),
    ]
    
    for i, (item, detail) in enumerate(checklist, 1):
        print(f"  {i:2}. [ ] {item:<30} - {detail}")
    
    print("\n" + "="*70)
    print("IMPORTANT: Product IDs must match EXACTLY (case-sensitive):")
    print("  • Monthly: com.pausely.premium.monthly")
    print("  • Annual:  com.pausely.premium.annual")
    print("="*70)

def generate_revenue_projection():
    """Generate revenue projection table"""
    print_step("REVENUE", "Projections & Pricing")
    
    print("\n📊 Pricing Comparison:")
    print(f"  Monthly:  $7.99/mo  = $95.88/year")
    print(f"  Annual:   $69.99/year")
    print(f"  Savings:  $28.89/year (34%)")
    
    print("\n💰 Revenue Share:")
    print("  Standard:  Apple 30%  |  You 70%")
    print("  Small Biz: Apple 15%  |  You 85% (if eligible)")
    
    print("\n📈 Example Revenue (Standard 70%):")
    scenarios = [
        ("100 monthly subscribers", 100, 7.99, 0.70),
        ("500 monthly subscribers", 500, 7.99, 0.70),
        ("1000 monthly subscribers", 1000, 7.99, 0.70),
        ("100 annual subscribers", 100, 69.99/12, 0.70),  # Monthly equivalent
    ]
    
    print(f"\n  {'Scenario':<30} {'Monthly Revenue':>15}")
    print("  " + "-"*50)
    for name, count, price, share in scenarios:
        revenue = count * price * share
        print(f"  {name:<30} ${revenue:>13.2f}")

def main():
    """Main function"""
    print_header("APP STORE CONNECT SETUP HELPER")
    print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("App: Pausely")
    print("Bundle ID: com.pausely.app.Pausely")
    
    print_step(1, "Prerequisites")
    print("""
Before creating products, ensure you have:
  ✓ Apple Developer Program membership ($99/year)
  ✓ App record created in App Store Connect
  ✓ Paid Apps agreement signed
  ✓ Tax and banking information complete
    """)
    
    print_step(2, "Product Summary")
    print(f"\nSubscription Group: {PRODUCTS['subscription_group']['reference_name']}")
    print(f"Group ID: {PRODUCTS['subscription_group']['group_id']}\n")
    
    for i, product in enumerate(PRODUCTS['products'], 1):
        print(f"  Product {i}: {product['name']}")
        print(f"    ID:       {product['product_id']}")
        print(f"    Price:    ${product['price_usd']}")
        print(f"    Duration: {product['duration']}")
        print(f"    Trial:    {product['trial']}")
        print(f"    Tier:     {product['tier']}")
        if 'savings' in product:
            print(f"    Savings:  {product['savings']}")
        print()
    
    generate_revenue_projection()
    print_verification_checklist()
    
    # Generate files
    print_step("FILES", "Generated")
    
    # Save quick guide
    guide = generate_markdown_guide()
    with open('APPSTORE_QUICK_GUIDE.md', 'w') as f:
        f.write(guide)
    print("  ✓ Created: APPSTORE_QUICK_GUIDE.md")
    
    # Save XML template
    xml = generate_appstore_xml()
    with open('appstore_products.xml', 'w') as f:
        f.write(xml)
    print("  ✓ Created: appstore_products.xml")
    
    # JSON already exists
    print("  ✓ Exists:  appstore_products.json")
    print("  ✓ Exists:  APP_STORE_CONNECT_SETUP.md")
    
    print_header("NEXT STEPS")
    print("""
1. Open https://appstoreconnect.apple.com
2. Navigate to your app → Subscriptions
3. Follow the detailed guide in:
   📄 APP_STORE_CONNECT_SETUP.md

OR use the quick reference:
   📄 APPSTORE_QUICK_GUIDE.md

4. Create sandbox testers for testing
5. Build and test purchases in Xcode
6. Submit for review when ready
    """)
    
    print("="*70)
    print("✅ Setup helper completed!")
    print("="*70 + "\n")

if __name__ == "__main__":
    main()
