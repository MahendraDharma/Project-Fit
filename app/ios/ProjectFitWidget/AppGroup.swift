import Foundation

enum AppGroup {
  static let identifier: String = {
    Bundle.main.object(forInfoDictionaryKey: "ProjectFitAppGroupIdentifier") as? String
      ?? "group.io.github.mahendradharma.projectfit"
  }()
}
