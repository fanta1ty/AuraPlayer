//
//  AuraButton.swift
//  AuraPlayer
//
//  Created by Thinh Nguyen on 4/7/26.
//
//  Reusable button with primary / secondary / icon-only variants.
//  Uses only design tokens — no hardcoded colors, fonts, or metrics.
//

import SwiftUI

enum AuraButtonVariant {
    case primary    // filled accent
    case secondary  // outlined on surface
    case icon       // circular icon-only
}

struct AuraButton: View {
    let title: String
    let systemImage: String?
    let variant: AuraButtonVariant
    let action: () -> Void

    init(_ title: String = "",
         systemImage: String? = nil,
         variant: AuraButtonVariant = .primary,
         action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            switch variant {
            case .icon:
                Image(systemName: systemImage ?? "circle")
                    .font(.auraHeadline)
                    .frame(width: 48, height: 48)
            default:
                HStack(spacing: AuraSpacing.sm) {
                    if let systemImage { Image(systemName: systemImage) }
                    if !title.isEmpty { Text(title).font(.auraHeadline) }
                }
                .padding(.horizontal, AuraSpacing.lg)
                .padding(.vertical, AuraSpacing.md)
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(AuraButtonStyle(variant: variant))
    }
}

private struct AuraButtonStyle: ButtonStyle {
    let variant: AuraButtonVariant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background(background)
            .overlay(border)
            .clipShape(shape)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch variant {
        case .primary: return .background
        case .secondary, .icon: return .accent
        }
    }

    @ViewBuilder private var background: some View {
        switch variant {
        case .primary: Color.accent
        case .secondary: Color.surface
        case .icon: Color.surfaceElevated
        }
    }

    @ViewBuilder private var border: some View {
        switch variant {
        case .secondary:
            shape.stroke(Color.accent.opacity(0.6), lineWidth: 1)
        default:
            EmptyView()
        }
    }

    private var shape: some Shape {
        switch variant {
        case .icon: return AnyShape(Circle())
        default:    return AnyShape(RoundedRectangle(cornerRadius: AuraRadius.medium))
        }
    }
}

/// Small scale + fade feedback for icon-style tap targets.
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.82 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview("AuraButton") {
    VStack(spacing: AuraSpacing.lg) {
        AuraButton("Play All", systemImage: "play.fill", variant: .primary) {}
        AuraButton("Shuffle", systemImage: "shuffle", variant: .secondary) {}
        HStack(spacing: AuraSpacing.lg) {
            AuraButton(systemImage: "backward.fill", variant: .icon) {}
            AuraButton(systemImage: "pause.fill", variant: .icon) {}
            AuraButton(systemImage: "forward.fill", variant: .icon) {}
        }
    }
    .padding(AuraSpacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.background)
    .preferredColorScheme(.dark)
}
