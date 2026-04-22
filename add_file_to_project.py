#!/usr/bin/env python3
"""Add ScreenTimeSetupView.swift to the Xcode project"""

import re

# Read the project file
with open('Pausely.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Generate new UUIDs
build_file_id = '9C0000012F8E8E9000C3D4E5'
file_ref_id = '9C0000002F8E8E9000C3D4E5'

# Check if already added
if 'ScreenTimeSetupView.swift' in content:
    print("ScreenTimeSetupView.swift is already referenced in the project")
    # Let's check if all 4 references are there
    count = content.count('ScreenTimeSetupView.swift')
    print(f"Found {count} references")
    if count >= 4:
        print("All references appear to be present")
        exit(0)

# 1. Add PBXBuildFile entry
build_file_entry = f'''\t\t{build_file_id} /* ScreenTimeSetupView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* ScreenTimeSetupView.swift */; }};
'''

# Find ReferralManager.swift PBXBuildFile and add after it
pattern = r'(\t\t9B0000022F6C7D9000B2C3D4 /\* ReferralManager\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = 9B0000012F6C7D9000B2C3D4 /\* ReferralManager\.swift \*/; \};\n)'
content = re.sub(pattern, r'\1' + build_file_entry, content)

# 2. Add PBXFileReference entry
file_ref_entry = f'''\t\t{file_ref_id} /* ScreenTimeSetupView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ScreenTimeSetupView.swift; sourceTree = "<group>"; }};
'''

# Find ReferralManager.swift PBXFileReference and add after it
pattern = r'(\t\t9B0000012F6C7D9000B2C3D4 /\* ReferralManager\.swift \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = ReferralManager\.swift; sourceTree = "<group>"; \};\n)'
content = re.sub(pattern, r'\1' + file_ref_entry, content)

# 3. Add to Views PBXGroup children
pattern = r'(\t\t\t\t9B0000012F6C7D9000B2C3D4 /\* ReferralManager\.swift \*/,\n\t\t\t\t9B0000032F6C7D9000B2C3D4 /\* ReferralPromotionView\.swift \*/,)'
replacement = r'\t\t\t\t' + file_ref_id + ' /* ScreenTimeSetupView.swift */,' + r'\n\t\t\t\t9B0000012F6C7D9000B2C3D4 /* ReferralManager.swift */,' + r'\n\t\t\t\t9B0000032F6C7D9000B2C3D4 /* ReferralPromotionView.swift */,'
content = re.sub(pattern, replacement, content)

# 4. Add to PBXSourcesBuildPhase
pattern = r'(\t\t\t\t9B0000022F6C7D9000B2C3D4 /\* ReferralManager\.swift in Sources \*/,\n)'
replacement = r'\t\t\t\t' + build_file_id + ' /* ScreenTimeSetupView.swift in Sources */,' + r'\n\t\t\t\t9B0000022F6C7D9000B2C3D4 /* ReferralManager.swift in Sources */,' + r'\n'
content = re.sub(pattern, replacement, content)

# Write the modified project file
with open('Pausely.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("Added ScreenTimeSetupView.swift to the project")
