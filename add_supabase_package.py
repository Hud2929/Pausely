#!/usr/bin/env python3
"""Fix supabase-swift package version requirement"""

import re

# Read the project file
with open('Pausely.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Find and replace the minimumVersion requirement
# Change from 2.5.1 to 2.0.0 to allow version 2.41.1
old_req = '''\t\t\tkind = upToNextMajorVersion;
\t\t\t\tminimumVersion = 2.5.1;'''

new_req = '''\t\t\tkind = upToNextMajorVersion;
\t\t\t\tminimumVersion = 2.0.0;'''

if 'minimumVersion = 2.5.1' in content:
    content = content.replace(old_req, new_req)
    print("Fixed minimumVersion from 2.5.1 to 2.0.0")
else:
    print("minimumVersion is not 2.5.1, skipping")

# Write the modified project file
with open('Pausely.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)
