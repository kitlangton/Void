import SwiftUI
import ComposableArchitecture

struct AmbienceSectionView: View {
  @Bindable var store: StoreOf<SettingsReducer>
  let ambientSounds: [AmbientSound]
  let upcomingAmbience: [String]
  let miniMode: Bool
  let isExpanded: Bool
  let otherSectionIsActive: Bool
  
  var body: some View {
    ControlSection(
      title: "Ambience",
      systemImage: "water.waves",
      selectedValue: store.settings.ambience?.title,
      isExpanded: isExpanded,
      onExpandedChange: { expanded in
        store.send(.select(expanded ? .ambient : nil), animation: .nice)
      },
      otherSectionIsActive: otherSectionIsActive,
      miniMode: miniMode
    ) {
      ambienceGrid
    }
    .accessibilityIdentifier("ambience-section")
  }
  
  @ViewBuilder
  private var ambienceGrid: some View {
    VStack(alignment: .center) {
      LazyVGrid(
        columns: [GridItem(.flexible()), GridItem(.flexible())],
        spacing: 8
      ) {
        offButton
        availableSounds
        comingSoonSounds
      }
    }
  }
  
  @ViewBuilder
  private var offButton: some View {
    SelectableButton(
      title: "Off",
      isSelected: store.settings.ambience == nil
    ) {
      store.send(.setAmbience(nil), animation: .nice)
    }
  }
  
  @ViewBuilder
  private var availableSounds: some View {
    ForEach(ambientSounds, id: \.self) { sound in
      SelectableButton(
        title: sound.title,
        isSelected: store.settings.ambience == sound
      ) {
        store.send(.setAmbience(sound), animation: .nice)
      }
    }
  }
  
  @ViewBuilder
  private var comingSoonSounds: some View {
    ForEach(upcomingAmbience, id: \.self) { sound in
      SelectableButton(
        title: sound,
        isSelected: false
      ) {
        print("Previewing \(sound)")
      }
      .disabled(true)
    }
  }
}