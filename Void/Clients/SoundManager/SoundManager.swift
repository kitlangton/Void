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
  var playAmbient: (_ sound: AmbientSound) async -> Void
  var stopCurrentAmbient: () async -> Void
  var preloadSounds: () async -> Void
}

extension SoundManagerClient: DependencyKey {
  static let testValue = Self(
    play: { _ in },
    stop: { _ in },
    stopAll: {},
    playAmbient: { _ in },
    stopCurrentAmbient: {},
    preloadSounds: {}
  )

  static var liveValue: SoundManagerClient {
    print("SoundManagerClient.liveValue")
    let live = SoundManagerLive()
    return SoundManagerClient(
      play: { await live.play($0) },
      stop: { await live.stop($0) },
      stopAll: { await live.stopAll() },
      playAmbient: { await live.playAmbient($0) },
      stopCurrentAmbient: { await live.stopCurrentAmbient() },
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
  private let ambientManager: AmbientManager

  init(ambientManager: AmbientManager = .shared) {
    self.ambientManager = ambientManager
  }

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
    await stopCurrentAmbient()
  }

  func playAmbient(_ sound: AmbientSound) async {
    await ambientManager.play(sound)
  }

  func stopCurrentAmbient() async {
    await ambientManager.stop()
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
