import Foundation

func latestVersion() throws -> String { try availableVersions()[0] }
func stableVersion() -> String { "5.4.2" }

func availableVersions() throws -> [String] { [stableVersion()] }
