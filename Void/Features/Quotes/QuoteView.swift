//
//  QuoteView.swift
//  Void
//
//  Created by Kit Langton on 11/17/24.
//

import Inject
import SwiftUI

struct QuotesView: View {
  @ObserveInjection var inject
  @State private var currentQuote: Quote = Quotes.random()

  var body: some View {
    Button {
      Task {
        await transitionToNewQuote()
      }
    } label: {
      QuoteView(quote: currentQuote)
        .id(currentQuote.id)
        .transition(.blurReplace)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.selection, trigger: currentQuote)
    .enableInjection()
  }

  func transitionToNewQuote() async {
    withAnimation(.spring) {
      currentQuote = Quotes.random(excluding: currentQuote)
    }
  }
}

struct QuoteView: View {
  @ObserveInjection var inject
  @State private var visibleLines: Set<Int> = []
  @State private var allVisible: Bool = false
  let quote: Quote

  var sourceVisible: Bool {
    visibleLines.contains(quote.lines.count)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(Array(quote.lines.enumerated()), id: \.element) { index, line in
        let visible = visibleLines.contains(index)
        Text(line)
          .fontWeight(.medium)
          .opacity(visible ? 1 : 0)
          .blur(radius: visible ? 0 : 5)
          .offset(y: visible ? 0 : 20)
          .scaleEffect(allVisible ? 1 : 1.02, anchor: .leading)
      }

      Text(quote.source)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)
        .font(.system(.subheadline))
        .opacity(sourceVisible ? 1 : 0)
        .blur(radius: sourceVisible ? 0 : 5)
        .offset(y: sourceVisible ? 0 : 20)
        .scaleEffect(allVisible ? 1 : 1.02, anchor: .leading)
    }
    .opacity(allVisible ? 0.6 : 1)
    .multilineTextAlignment(.leading)
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal)
    .padding(.top)
    .task {
      await animateIn()
    }
    .drawingGroup()
    .enableInjection()
  }

  func animateIn() async {
    visibleLines = []
    allVisible = false
    for i in 0 ... quote.lines.count {
      try? await Task.sleep(for: .seconds(0.1))
      withAnimation(.spring(duration: 0.8)) {
        visibleLines.insert(i)
        ()
      }
    }
    try? await Task.sleep(for: .seconds(0.5))
    withAnimation(.easeInOut(duration: 1.8)) {
      allVisible = true
    }
  }
}
