//
//  ControlSection.swift
//  Void
//
//  Created by Kit Langton on 11/16/24.
//

import Inject
import Pow
import SwiftUI

struct ControlSection<Content: View>: View {
  @ObserveInjection var inject

  let title: String
  let systemImage: String
  let selectedValue: String?
  let isExpanded: Bool
  let onExpandedChange: (Bool) -> Void
  let otherSectionIsActive: Bool
  var miniMode: Bool
  @ViewBuilder let content: Content

  var expandedMode: Bool {
    !miniMode || isExpanded
  }

  private var isEnabled: Bool {
    selectedValue != nil
  }

  var body: some View {
    VStack(spacing: 0) {
      Button {
        onExpandedChange(!isExpanded)
      } label: {
        HStack {
          HStack {
            Image(systemName: !isEnabled ? systemImage : "\(systemImage)")
              .symbolVariant(.fill)
              .animation(.nice, value: isEnabled)
              .foregroundStyle(isEnabled ? .pink.opacity(0.9) : Color.primary.opacity(0.4))
              .frame(width: 18)
              .padding(.trailing, 4)
              .fontWeight(.black)

            if expandedMode {
              Text(title)
                .fontWeight(.medium)
                .transition(.blurReplace)
            }
          }
          .opacity(isEnabled ? 1 : 0.55)

          if expandedMode {
            Spacer()
          }

          VStack {
            if let selectedValue {
              Text(selectedValue)
                .lineLimit(1)
                .contentTransition(.numericText())
                .transition(.blurReplace.animation(.nice))
                .foregroundStyle(.primary.opacity(0.8))
                .font(.system(miniMode ? .callout : .body))
                .transition(.blurReplace.animation(.nice))

            } else {
              VStack {
                Text(title == "Timer" ? "∞" : "—")
                  .fontWeight(.bold)
                  .foregroundStyle(.tertiary)
                  .transition(.blurReplace.animation(.nice))
              }
              .frame(width: 16)
            }
          }
          .changeEffect(.glow(color: .white), value: selectedValue)
        }
        .padding(.vertical, expandedMode ? 12 : 6)
        .padding(.horizontal, 12)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)

      if isExpanded {
        content
          .padding(.horizontal, 12)
          .padding(.top, 12)
          .transition(.opacity.combined(with: .blurReplace).animation(.nice))
      }
    }
    .padding(.top, isExpanded ? 2 : 0)
    .padding(.bottom, isExpanded ? 8 : 0)
    .blur(radius: otherSectionIsActive ? 1 : 0)
    .drawingGroup()
    .background {
      RoundedRectangle(cornerRadius: 12)
        .fill(.thickMaterial)
        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
        .opacity(isExpanded ? 0.7 : 0)
        .mask {
          LinearGradient(
            stops: [
              .init(color: .white, location: 0),
              .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        }
    }
    .opacity(otherSectionIsActive ? 0.6 : 1)
    .padding(.bottom, isExpanded ? 12 : 0)
    .enableInjection()
  }
}
