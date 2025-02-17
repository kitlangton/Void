//

//  VoidApp.swift
//  Void
//
//  Created by Kit Langton on 6/23/24.
//

import ComposableArchitecture
import Inject
import SwiftData
import SwiftUI

@main
struct VoidApp: App {
  static let store =
    Store(initialState: HomeReducer.State()) {
      HomeReducer()
    } withDependencies: {
      if isTesting {
        $0.defaultFileStorage = .inMemory
      }
    }

  var body: some Scene {
    WindowGroup {
      if isTesting {
        EmptyView()
      } else {
        HomeView(store: VoidApp.store)
      }
    }
  }
}
