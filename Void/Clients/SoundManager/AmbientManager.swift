import AVFoundation
import Foundation
import MediaPlayer
import SwiftUI

@MainActor
final class AmbientManager {
  static let shared = AmbientManager()

  private struct Player {
    let node: AVAudioPlayerNode
    let filter: AVAudioUnitEQ
    let file: AVAudioFile
  }

  private let audioSession = AVAudioSession.sharedInstance()
  private var engine = AVAudioEngine()
  private var players: [AmbientSound: Player] = [:]
  private var fadeTimers: [AmbientSound: Timer] = [:]
  private var effectTimer: Timer?
  private var playbackGenerations: [AmbientSound: Int] = [:]
  private var currentSound: AmbientSound?
  private var isPlaying = false
  private var isPaused = false

  init() {
    activateAudioSession()
    setupPlayers()
    setupRemoteCommandCenter()
    setupNotifications()
  }

  func play(_ sound: AmbientSound) {
    let targetVolume: Float = isPaused ? 0.6 : 1
    if currentSound == sound,
       let player = players[sound],
       player.node.isPlaying,
       player.node.volume >= targetVolume - 0.01
    {
      return
    }

    activateAudioSession()
    startEngine()

    if let oldSound = currentSound, oldSound != sound {
      fadeOut(oldSound)
    }

    currentSound = sound
    isPlaying = true

    if players[sound] == nil {
      loadSound(sound)
    }
    guard let player = players[sound] else { return }

    if !player.node.isPlaying {
      player.node.volume = 0
      let generation = (playbackGenerations[sound] ?? 0) + 1
      playbackGenerations[sound] = generation
      scheduleLoop(sound, generation: generation)
      player.node.play()
    }

    fadeTimers[sound]?.invalidate()
    fadeTimers[sound] = nil
    fadeIn(sound)
    updateNowPlayingInfo(for: sound)
  }

  func stop() {
    isPlaying = false
    isPaused = false
    effectTimer?.invalidate()
    effectTimer = nil

    for (sound, player) in players where player.node.isPlaying {
      fadeOut(sound)
    }

    currentSound = nil
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }

  func setPaused(_ paused: Bool) {
    isPaused = paused
    guard let currentSound, let player = players[currentSound], player.node.isPlaying else { return }

    fadeTimers[currentSound]?.invalidate()
    fadeTimers[currentSound] = nil
    effectTimer?.invalidate()

    let startVolume = player.node.volume
    let endVolume: Float = paused ? 0.6 : 1
    let startFrequency = player.filter.bands[0].frequency
    let endFrequency: Float = paused ? 850 : 20_000
    let duration: TimeInterval = 0.35
    let stepDuration: TimeInterval = 0.02
    let steps = Int(duration / stepDuration)
    var currentStep = 0

    effectTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
      Task { @MainActor [weak self] in
        guard let self, let player = self.players[currentSound] else {
          timer.invalidate()
          return
        }

        currentStep += 1
        let progress = min(Float(currentStep) / Float(steps), 1)
        player.node.volume = startVolume + (endVolume - startVolume) * progress

        let logFrequency = log(startFrequency) + (log(endFrequency) - log(startFrequency)) * progress
        player.filter.bands[0].frequency = exp(logFrequency)

        if currentStep >= steps {
          timer.invalidate()
          self.effectTimer = nil
        }
      }
    }
  }

  private func fadeIn(_ sound: AmbientSound) {
    guard let player = players[sound] else { return }
    fade(sound, from: player.node.volume, to: isPaused ? 0.6 : 1)
  }

  private func fadeOut(_ sound: AmbientSound) {
    guard let player = players[sound] else { return }
    fade(sound, from: player.node.volume, to: 0) { [weak self] in
      guard let self else { return }
      self.playbackGenerations[sound, default: 0] += 1
      player.node.stop()
      if self.currentSound == sound {
        self.currentSound = nil
      }
    }
  }

  private func fade(
    _ sound: AmbientSound,
    from startVolume: Float,
    to endVolume: Float,
    completion: (() -> Void)? = nil
  ) {
    fadeTimers[sound]?.invalidate()
    guard players[sound] != nil else {
      completion?()
      return
    }

    let stepDuration: TimeInterval = 0.05
    let steps = Int(1.5 / stepDuration)
    var currentStep = 0

    fadeTimers[sound] = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
      Task { @MainActor [weak self] in
        guard let self, let player = self.players[sound] else {
          timer.invalidate()
          completion?()
          return
        }

        currentStep += 1
        let progress = Float(currentStep) / Float(steps)
        player.node.volume = startVolume + (endVolume - startVolume) * progress

        if currentStep >= steps {
          timer.invalidate()
          self.fadeTimers[sound] = nil
          completion?()
        }
      }
    }
  }

  private func activateAudioSession() {
    do {
      try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try audioSession.setActive(true)
    } catch {
      print("Failed to set up audio session: \(error)")
    }
  }

  private func startEngine() {
    guard !engine.isRunning else { return }
    do {
      try engine.start()
    } catch {
      print("Failed to start ambient audio engine: \(error)")
    }
  }

  private func pauseForInterruption() {
    fadeTimers.values.forEach { $0.invalidate() }
    fadeTimers.removeAll()
    effectTimer?.invalidate()
    effectTimer = nil
    engine.pause()
  }

  private func resumeCurrentSoundIfNeeded() {
    guard isPlaying, let currentSound else { return }
    startEngine()
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
    AmbientSound.allCases.forEach(loadSound)
    engine.prepare()
  }

  private func loadSound(_ sound: AmbientSound) {
    let fileInfo = sound.fileInfo
    guard let url = Bundle.main.url(
      forResource: fileInfo.fileName,
      withExtension: fileInfo.fileExtension
    ) else { return }

    do {
      let file = try AVAudioFile(forReading: url)
      let node = AVAudioPlayerNode()
      let filter = AVAudioUnitEQ(numberOfBands: 1)
      let band = filter.bands[0]
      band.filterType = .lowPass
      band.frequency = isPaused ? 850 : 20_000
      band.bandwidth = 0.5
      band.bypass = false

      engine.attach(node)
      engine.attach(filter)
      engine.connect(node, to: filter, format: file.processingFormat)
      engine.connect(filter, to: engine.mainMixerNode, format: file.processingFormat)
      players[sound] = Player(node: node, filter: filter, file: file)
    } catch {
      print("Error loading ambient sound: \(error)")
    }
  }

  private func scheduleLoop(_ sound: AmbientSound, generation: Int) {
    guard let player = players[sound], playbackGenerations[sound] == generation else { return }
    player.node.scheduleSegment(
      player.file,
      startingFrame: 0,
      frameCount: AVAudioFrameCount(player.file.length),
      at: nil,
      completionCallbackType: .dataConsumed
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.scheduleLoop(sound, generation: generation)
      }
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
    else { return }

    switch type {
    case .began:
      pauseForInterruption()
    case .ended:
      activateAudioSession()
      let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt
      let options = optionsValue.map(AVAudioSession.InterruptionOptions.init(rawValue:))
      if options?.contains(.shouldResume) != false {
        resumeCurrentSoundIfNeeded()
      }
    @unknown default:
      break
    }
  }

  @objc private func handleRouteChange(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
          AVAudioSession.RouteChangeReason(rawValue: reasonValue) == .oldDeviceUnavailable
    else { return }

    activateAudioSession()
    resumeCurrentSoundIfNeeded()
  }

  @objc private func handleMediaServicesReset() {
    fadeTimers.values.forEach { $0.invalidate() }
    fadeTimers.removeAll()
    effectTimer?.invalidate()
    effectTimer = nil
    playbackGenerations.removeAll()
    players.removeAll()
    engine = AVAudioEngine()

    activateAudioSession()
    setupPlayers()
    resumeCurrentSoundIfNeeded()
  }
}
