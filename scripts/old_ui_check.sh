#!/bin/bash
# Lists every Swift file that still contains old (pre Ink and Paper) UI, with a count of old
# markers per file. The redesign is finished when this prints "0 files". See the pausely-design skill.
cd "$(dirname "$0")/.."
PATTERN='accentMint|obsidian|glassCard|glassBackground|\.glass\(|premiumButton|AnimatedGradientBackground|PremiumBackground|LinearGradient|RadialGradient|AngularGradient|\.shadow\(|ultraThinMaterial|surfaceCard|BrandColors|BackgroundColors|STFont|AppTypography|HapticStyle|STAnimation|PrimaryButtonStyle|GhostButtonStyle|PremiumAnimations|brandPrimary|backgroundPrimary|semanticDestructive|semanticWarning|semanticSuccess|semanticInfo'
grep -rcE "$PATTERN" Pausely PauselyWidget --include='*.swift' \
  | grep -v ':0$' \
  | grep -vE 'Core/Design/AppColors.swift|DesignSystem/GlassModifier.swift|DesignSystem/SurfaceCard.swift|Core/Design/(Typography|AppTypography|Animation|Spacing).swift' \
  | sort -t: -k2 -nr | tee /dev/stderr | wc -l | xargs -I{} echo "{} files still have old UI"
