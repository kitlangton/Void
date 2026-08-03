//
//  SoundManager.swift
//  Void
//
//  Created by Kit Langton on 11/17/24.
//

import AVFoundation
import Dependencies
import DependenciesMacros
import Foundation
import Inject
import SwiftUI

@DependencyClient
struct SoundManagerClient {
  var play: (_ sound: Sound) async -> Void
  var stop: (_ sound: Sound) async -> Void
  var stopAll: () async -> Void
  var setAmbient: (_ sound: AmbientSound?) async -> Void
  var setAmbientPaused: (_ paused: Bool) async -> Void
  var preloadSounds: () async -> Void
}

extension SoundManagerClient: DependencyKey {
  static let testValue = Self(
    play: { _ in },
    stop: { _ in },
    stopAll: {},
    setAmbient: { _ in },
    setAmbientPaused: { _ in },
    preloadSounds: {}
  )

  static var liveValue: SoundManagerClient {
    print("SoundManagerClient.liveValue")
    let live = SoundManagerLive()
    return SoundManagerClient(
      play: { await live.play($0) },
      stop: { await live.stop($0) },
      stopAll: { await live.stopAll() },
      setAmbient: { await live.setAmbient($0) },
      setAmbientPaused: { await live.setAmbientPaused($0) },
      preloadSounds: { await live.preloadSounds() }
    )
  }
}

extension DependencyValues {
  var soundManager: SoundManagerClient {
    get { self[SoundManagerClient.self] }
    set { self[SoundManagerClient.self] = newValue }
  }
}

// MARK: - SoundManager

final actor SoundManagerLive {
  // MARK: - Public Methods

  func play(_ sound: Sound) {
    setupAudioSession()

    guard let player = audioPlayers[sound] else {
      print("Sound not found: \(sound)")
      return
    }
    player.currentTime = 0
    player.play()
  }

  func stop(_ sound: Sound) {
    audioPlayers[sound]?.stop()
  }

  func stopAll() async {
    audioPlayers.values.forEach { $0.stop() }
    await setAmbient(nil)
  }

  func setAmbient(_ sound: AmbientSound?) async {
    if let sound {
      await AmbientManager.shared.play(sound)
    } else {
      await AmbientManager.shared.stop()
    }
  }

  func setAmbientPaused(_ paused: Bool) async {
    await AmbientManager.shared.setPaused(paused)
  }

  private var audioPlayers: [Sound: AVAudioPlayer] = [:]

  func preloadSounds() async {
    await withTaskGroup(of: Void.self) { group in
      for sound in Sound.allCases {
        group.addTask { [weak self] in
          await self?.loadSound(sound)
        }
      }
    }
  }

  // MARK: - Private Methods

  private func setupAudioSession() {
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode: .default,
        options: [.mixWithOthers]
      )
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Failed to setup audio session: \(error.localizedDescription)")
    }
  }

  private func loadSound(_ sound: Sound) async {
    guard let url = Bundle.main.url(
      forResource: sound.fileInfo.fileName,
      withExtension: sound.fileInfo.fileExtension
    ) else {
      print("Failed to find sound file: \(sound.fileInfo.fileName).\(sound.fileInfo.fileExtension)")
      return
    }

    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.prepareToPlay()
      audioPlayers[sound] = player
    } catch {
      print("Failed to load sound \(sound): \(error.localizedDescription)")
    }
  }
}
