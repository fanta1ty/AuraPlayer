//
//  AuraTheme.swift
//  AuraPlayer
//
//  Created by Thinh Nguyen on 4/7/26.
//
//  Central design-system hub. In a single-module app all tokens are already
//  globally visible; this file documents the system and provides namespaced
//  aliases so you can write AuraTheme.Spacing.md, AuraTheme.Radius.large, etc.
//
//  Tokens:     AuraColors.swift (Color extensions)
//              AuraFonts.swift  (Font extensions + Aura.fontDesign)
//              AuraLayout.swift (AuraSpacing, AuraRadius, .cardShadow, .glowEffect)
//  Components: AuraButton, AuraCard, AuraSlider, AuraProgressRing
//  Signature effect: cyan .glowEffect() - defined in AuraLayout.swift
//

import SwiftUI

enum AuraTheme {
    typealias Spacing = AuraSpacing
    typealias Radius  = AuraRadius
    
    /// Global font design switch (mirrors Aura.fontDesign)
    static var fontDesign: Font.Design { Aura.fontDesign }
}
