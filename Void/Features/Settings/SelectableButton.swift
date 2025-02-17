//
//  SelectableButton.swift
//  Void
//
//  Created by Kit Langton on 11/16/24.
//

import Inject
import SwiftUI

struct SelectableButton: View {
  @ObserveInjection var inject

  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      if isSelected {
        Text(title)
          .font(.system(.title3).weight(.bold))
          .contentTransition(.numericText())
      } else {
        Text(title)
          .font(.system(.title3).weight(.medium))
          .contentTransition(.numericText())
      }
    }
    .opacity(isSelected ? 1 : 0.6)
    .animation(.interactiveSpring, value: isSelected)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 6)
    .contentShape(.rect)
    .buttonStyle(.plain)
    .enableInjection()
    .sensoryFeedback(.selection, trigger: isSelected)
    .drawingGroup()
  }
}
