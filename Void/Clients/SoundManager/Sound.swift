struct FileInfo {
  let fileName: String
  let fileExtension: String
}

enum Sound: CaseIterable {
  case startBell
  case intervalBell
  case completionBell

  var fileInfo: FileInfo {
    switch self {
    case .startBell: FileInfo(fileName: "start-bell-1", fileExtension: "wav")
    case .intervalBell: FileInfo(fileName: "interval-bell-1", fileExtension: "mp3")
    case .completionBell: FileInfo(fileName: "end-bell-1", fileExtension: "mp3")
    }
  }
}

enum AmbientSound: String, CaseIterable, Codable {
  case rain = "Rain"
  case waterfall = "Waterfall"

  var fileInfo: FileInfo {
    switch self {
    case .rain: FileInfo(fileName: "city-rain", fileExtension: "m4a")
    case .waterfall: FileInfo(fileName: "waterfall", fileExtension: "m4a")
    }
  }

  var title: String {
    return rawValue
  }
}
