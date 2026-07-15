//
//  StarRatingView.swift
//  AuraPlayer
//
//  Created by mobile on 16/7/26.
//
//  5-star rating. Read-only by default; set interactive to allow tapping.
//

import SwiftUI

struct StarRatingView: View {
    let rating: Int
    var size: CGFloat = 12
    var interactive: Bool = false
    var onChange: ((Int) -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size, weight: .medium))
                    .foregroundStyle(star <= rating ? Color.accent : Color.textTertiary)
                    .frame(width: interactive ? size * 2.1 : size + 2,
                           height: interactive ? size * 2.1 : size)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard interactive else { return }
                        onChange?(star == rating ? 0 : star)
                    }
            }
        }
    }
}

#Preview {
    VStack(spacing: AuraSpacing.lg) {
        StarRatingView(rating: 0)
        StarRatingView(rating: 3)
        StarRatingView(rating: 5, size: 20)
    }
    .padding(AuraSpacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.background)
    .preferredColorScheme(.dark)
}
