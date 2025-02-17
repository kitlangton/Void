import ComposableArchitecture
import Foundation

struct MeditationState: Equatable, Codable {
	var elapsedTime: ElapsedTime

	init(now: Date) {
		elapsedTime = ElapsedTime(startedAt: now)
	}

	var isPaused: Bool {
		elapsedTime.isPaused
	}

	func secondsElapsed(now: Date) -> Int {
		elapsedTime.secondsElapsed(now: now)
	}

	func elapsed(now: Date) -> TimeInterval {
		elapsedTime.elapsed(now: now)
	}
}

extension SharedReaderKey
	where Self == FileStorageKey<MeditationState?>.Default
{
	static var meditationState: Self {
		Self[
			.fileStorage(.documentsDirectory.appending(component: "meditation-state.json")),
			default: nil
		]
	}
}
