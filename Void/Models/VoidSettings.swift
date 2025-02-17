import ComposableArchitecture
import Foundation

struct VoidSettings: Equatable, Codable {
  var intervalSeconds: Int?
  var durationSeconds: Int?
  var ambience: AmbientSound?

  var intervalMinutes: Int? {
    get { intervalSeconds.map { $0 / 60 } }
    set { intervalSeconds = newValue.map { $0 * 60 } }
  }

  var durationMinutes: Int? {
    get { durationSeconds.map { $0 / 60 } }
    set { durationSeconds = newValue.map { $0 * 60 } }
  }
}

extension SharedReaderKey
  where Self == FileStorageKey<VoidSettings>.Default
{
  static var settings: Self {
    Self[.fileStorage(.documentsDirectory.appending(component: "settings.json")), default: VoidSettings()]
  }
}
