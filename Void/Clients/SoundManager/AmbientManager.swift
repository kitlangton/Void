import AVFoundation
import Foundation
import MediaPlayer
import SwiftUI

@MainActor
final class AmbientManager {
  static let shared = AmbientManager()

  private let audioSession = AVAudioSession.sharedInstance()
  private var players: [AmbientSound: AVAudioPlayer] = [:]
  private var fadeTimers: [AmbientSound: Timer] = [:]
  private var currentSound: AmbientSound?
  private var isPlaying: Bool = false

  init() {
    activateAudioSession()
    setupPlayers()
    setupRemoteCommandCenter()
    setupNotifications()
  }

  func play(_ sound: AmbientSound) {
    // If we're already playing this sound at full volume, do nothing
    if currentSound == sound,
       let player = players[sound],
       player.isPlaying,
       player.volume >= 0.99
    {
      return
    }

    activateAudioSession()

    let previousSound = currentSound

    // If this isn't the current sound, fade out the current sound
    if let oldSound = previousSound, oldSound != sound {
      fadeOut(oldSound)
    }

    currentSound = sound
    isPlaying = true

    if players[sound] == nil {
      loadSound(sound)
    }

    guard let player = players[sound] else { return }

    // If the player isn't playing, start it at 0 volume
    if !player.isPlaying {
      player.volume = 0
      player.play()
    }
    // Otherwise keep its current volume (it might be in the middle of fading out)

    // Cancel any existing fade for this sound (it might be fading out)
    fadeTimers[sound]?.invalidate()
    fadeTimers[sound] = nil

    // Fade in from current volume (whether it's 0 or mid-fade)
    fadeIn(sound)
    updateNowPlayingInfo(for: sound)
  }

  func stop() {
    isPlaying = false

    // Fade out all playing sounds
    for (sound, player) in players where player.isPlaying {
      fadeOut(sound)
    }

    currentSound = nil
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }

  private func fadeIn(_ sound: AmbientSound) {
    guard let player = players[sound] else { return }

    // let targetVolume = Float(MeditationSettings.shared.ambientVolume)
    let targetVolume = Float(1.0)
    fade(sound, from: player.volume, to: targetVolume)
  }

  private func fadeOut(_ sound: AmbientSound) {
    guard let player = players[sound] else { return }
    fade(sound, from: player.volume, to: 0) { [weak self] in
      guard let self = self else { return }
      player.stop()
      // Only clear current sound if this is still the current sound
      if self.currentSound == sound {
        self.currentSound = nil
      }
    }
  }

  private func fade(_ sound: AmbientSound, from startVolume: Float, to endVolume: Float, completion: (() -> Void)? = nil) {
    // Cancel any existing fade for this sound
    fadeTimers[sound]?.invalidate()

    guard let player = players[sound] else {
      completion?()
      return
    }

    let duration: TimeInterval = 1.5
    let stepDuration: TimeInterval = 0.05
    let steps = Int(duration / stepDuration)

    var currentStep = 0

    fadeTimers[sound] = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
      Task { @MainActor [weak self] in
        guard let self = self else {
          timer.invalidate()
          completion?()
          return
        }

        currentStep += 1
        let progress = Double(currentStep) / Double(steps)
        let newVolume = startVolume + (endVolume - startVolume) * Float(progress)

        player.volume = newVolume

        if currentStep >= steps {
          timer.invalidate()
          fadeTimers[sound] = nil

          if newVolume == 0 {
            player.stop()
          }

          completion?()
        }
      }
    }
  }

  private func activateAudioSession() {
    do {
      try audioSession.setCategory(
        .playback,
        mode: .default,
        options: [.mixWithOthers]
      )
      try audioSession.setActive(true)
    } catch {
      print("Failed to set up audio session: \(error)")
    }
  }

  private func pauseForInterruption() {
    for timer in fadeTimers.values {
      timer.invalidate()
    }
    fadeTimers.removeAll()

    for player in players.values where player.isPlaying {
      player.pause()
    }
  }

  private func resumeCurrentSoundIfNeeded() {
    guard isPlaying, let currentSound else { return }
    play(currentSound)
  }

  private func setupRemoteCommandCenter() {
    let commandCenter = MPRemoteCommandCenter.shared()

    commandCenter.playCommand.addTarget { [weak self] _ in
      if let currentSound = self?.currentSound {
        self?.play(currentSound)
        return .success
      }
      return .commandFailed
    }

    commandCenter.pauseCommand.addTarget { [weak self] _ in
      self?.stop()
      return .success
    }
  }

  private func setupPlayers() {
    for sound in AmbientSound.allCases {
      loadSound(sound)
    }
  }

  private func loadSound(_ sound: AmbientSound) {
    let fileInfo = sound.fileInfo
    guard let url = Bundle.main.url(forResource: fileInfo.fileName,
                                    withExtension: fileInfo.fileExtension) else { return }

    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.numberOfLoops = -1 // Loop indefinitely
      player.volume = 0.0 // Start muted
      players[sound] = player
      player.prepareToPlay()
    } catch {
      print("Error loading ambient sound: \(error)")
    }
  }

  private func updateNowPlayingInfo(for sound: AmbientSound) {
    var nowPlayingInfo = [String: Any]()
    nowPlayingInfo[MPMediaItemPropertyTitle] = sound.rawValue
    nowPlayingInfo[MPMediaItemPropertyArtist] = "Void"
    if let image = UIImage(named: "Logo") {
      nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }

  private func setupNotifications() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleInterruption),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleRouteChange),
      name: AVAudioSession.routeChangeNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleMediaServicesReset),
      name: AVAudioSession.mediaServicesWereResetNotification,
      object: nil
    )
  }

  @objc private func handleInterruption(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue)
    else {
      return
    }

    switch type {
    case .began:
      // Preserve the selected sound so it can be restarted when the interruption ends.
      pauseForInterruption()
    case .ended:
      activateAudioSession()

      guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
        resumeCurrentSoundIfNeeded()
        return
      }

      let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
      if options.contains(.shouldResume) {
        resumeCurrentSoundIfNeeded()
      }
    @unknown default:
      break
    }
  }

  @objc private func handleRouteChange(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
    else {
      return
    }

    // Handle route changes (e.g., headphones disconnected)
    switch reason {
    case .oldDeviceUnavailable:
      activateAudioSession()
      resumeCurrentSoundIfNeeded()
    default:
      break
    }
  }

  @objc private func handleMediaServicesReset() {
    // AVAudioPlayers become invalid after a media services reset and must be recreated.
    for timer in fadeTimers.values {
      timer.invalidate()
    }
    fadeTimers.removeAll()

    players.removeAll()

    activateAudioSession()
    setupPlayers()
    resumeCurrentSoundIfNeeded()
  }
}
