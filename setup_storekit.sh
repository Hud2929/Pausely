#!/bin/bash

echo "Setting up StoreKit Configuration..."
echo ""

# Check if we're in the right directory
if [ ! -f "Pausely.xcodeproj/project.pbxproj" ]; then
    echo "Error: Run this script from your Pausely project directory"
    echo "Current directory: $(pwd)"
    exit 1
fi

# Check if Products.storekit exists
if [ -f "Products.storekit" ]; then
    echo "Products.storekit already exists!"
else
    echo "Creating Products.storekit..."
    cat > Products.storekit << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>identifier</key>
    <string>pausely-products</string>
    <key>subscriptionGroups</key>
    <array>
        <dict>
            <key>identifier</key>
            <string>com.pausely.pro</string>
            <key>name</key>
            <string>Pausely Pro</string>
            <key>subscriptions</key>
            <array>
                <dict>
                    <key>displayPrice</key>
                    <string>$7.99</string>
                    <key>identifier</key>
                    <string>com.pausely.premium.monthly</string>
                    <key>period</key>
                    <string>P1M</string>
                    <key>referenceName</key>
                    <string>Monthly Pro</string>
                </dict>
                <dict>
                    <key>displayPrice</key>
                    <string>$69.99</string>
                    <key>identifier</key>
                    <string>com.pausely.premium.annual</string>
                    <key>period</key>
                    <string>P1Y</string>
                    <key>referenceName</key>
                    <string>Annual Pro</string>
                </dict>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF
    echo "Created Products.storekit"
fi

echo ""
echo "NEXT STEPS:"
echo "1. Open Pausely.xcodeproj in Xcode"
echo "2. Drag Products.storekit into the project navigator"
echo "3. Click your scheme → Edit Scheme → Run → Options"
echo "4. Select 'Products' under StoreKit Configuration"
echo "5. Add In-App Purchase capability"
echo ""
echo "File location: $(pwd)/Products.storekit"
