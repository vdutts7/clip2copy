import Cocoa
import Foundation

/// clip2copy - auto-copy macOS screenshots to clipboard
/// Author: vdutts7 (https://vd7.io)
/// Source: https://github.com/vdutts7/clip2copy
/// License: MIT

let VERSION = "1.3.2"
let AUTHOR = "vdutts7"
let HOMEPAGE = "https://vd7.io"
let REPO = "https://github.com/vdutts7/clip2copy"

struct Clip2CopyConfig: Codable {
    var location: String
    var rename: Bool
    var renamePrefix: String
    var disableShadow: Bool

    init(location: String, rename: Bool, renamePrefix: String = "", disableShadow: Bool) {
        self.location = location
        self.rename = rename
        self.renamePrefix = renamePrefix
        self.disableShadow = disableShadow
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        location = try c.decode(String.self, forKey: .location)
        rename = try c.decode(Bool.self, forKey: .rename)
        renamePrefix = try c.decodeIfPresent(String.self, forKey: .renamePrefix) ?? ""
        disableShadow = try c.decode(Bool.self, forKey: .disableShadow)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(location, forKey: .location)
        try c.encode(rename, forKey: .rename)
        try c.encode(renamePrefix, forKey: .renamePrefix)
        try c.encode(disableShadow, forKey: .disableShadow)
    }

    enum CodingKeys: String, CodingKey {
        case location, rename, renamePrefix, disableShadow
    }

    static func defaultLocation() -> String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads").path
    }

    static func configDir() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/clip2copy", isDirectory: true)
    }

    static func configURL() -> URL {
        configDir().appendingPathComponent("config.json")
    }

    static func load() -> Clip2CopyConfig? {
        let url = configURL()
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Clip2CopyConfig.self, from: data)
    }

    static func loadOrDefault() -> Clip2CopyConfig {
        load() ?? Clip2CopyConfig(
            location: defaultLocation(),
            rename: true,
            renamePrefix: "",
            disableShadow: true
        )
    }

    func save() throws {
        let dir = Self.configDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(self)
        try data.write(to: Self.configURL(), options: .atomic)
    }
}

enum Shell {
    @discardableResult
    static func run(_ launchPath: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (process.terminationStatus, output)
        } catch {
            return (127, error.localizedDescription)
        }
    }
}

enum ScreenshotSettings {
    /// macOS default when `com.apple.screencapture location` is unset.
    static let systemDefaultPath: String = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop").path
    }()

    static func effectiveLocation() -> String {
        let result = Shell.run("/usr/bin/defaults", ["read", "com.apple.screencapture", "location"])
        guard result.status == 0, !result.output.isEmpty else { return systemDefaultPath }
        return expandPath(result.output)
    }

    static func disableShadowEnabled() -> Bool? {
        let result = Shell.run("/usr/bin/defaults", ["read", "com.apple.screencapture", "disable-shadow"])
        guard result.status == 0 else { return nil }
        return result.output == "1"
    }

    static func apply(config: Clip2CopyConfig) throws {
        let location = try validateLocation(config.location, createIfMissing: true)
        _ = Shell.run("/usr/bin/defaults", ["write", "com.apple.screencapture", "location", location])
        _ = Shell.run("/usr/bin/defaults", [
            "write", "com.apple.screencapture", "disable-shadow",
            "-bool", config.disableShadow ? "true" : "false",
        ])
        _ = Shell.run("/usr/bin/killall", ["SystemUIServer"])
    }
}

enum ConfigError: Error, CustomStringConvertible {
    case notADirectory(String)
    case notWritable(String)
    case invalidKey(String)
    case invalidValue(String)
    case missingArgument(String)

    var description: String {
        switch self {
        case .notADirectory(let path): return "Not a directory: \(path)"
        case .notWritable(let path): return "Directory is not writable: \(path)"
        case .invalidKey(let key): return "Unknown config key: \(key)"
        case .invalidValue(let msg): return msg
        case .missingArgument(let msg): return msg
        }
    }
}

func expandPath(_ path: String) -> String {
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed == "~" {
        return FileManager.default.homeDirectoryForCurrentUser.path
    }
    if trimmed.hasPrefix("~/") {
        return FileManager.default.homeDirectoryForCurrentUser.path + String(trimmed.dropFirst(1))
    }
    if trimmed == "desktop" || trimmed == "Desktop" {
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop").path
    }
    if trimmed == "downloads" || trimmed == "Downloads" {
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads").path
    }
    return (trimmed as NSString).expandingTildeInPath
}

func validatePrefix(_ input: String) throws -> String {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "" }
    guard trimmed.count <= 32 else {
        throw ConfigError.invalidValue("Prefix too long (max 32 chars)")
    }
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
    guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
        throw ConfigError.invalidValue("Invalid prefix '\(trimmed)': use letters, numbers, _ - only")
    }
    return trimmed
}

func renameExample(_ prefix: String) -> String {
    prefix.isEmpty ? "a1b2c3.png" : "\(prefix)-a1b2c3.png"
}

func prefixDisplay(_ prefix: String) -> String {
    prefix.isEmpty ? "(none)" : prefix
}

func validateLocation(_ input: String, createIfMissing: Bool = true) throws -> String {
    let path = expandPath(input)
    guard !path.isEmpty else {
        throw ConfigError.invalidValue("Path cannot be empty")
    }

    let fm = FileManager.default
    var isDir: ObjCBool = false

    if fm.fileExists(atPath: path, isDirectory: &isDir) {
        guard isDir.boolValue else {
            throw ConfigError.notADirectory(path)
        }
    } else if createIfMissing {
        let parent = (path as NSString).deletingLastPathComponent
        if !parent.isEmpty && parent != "/" && !fm.fileExists(atPath: parent) {
            _ = try validateLocation(parent, createIfMissing: true)
        }
        do {
            try fm.createDirectory(atPath: path, withIntermediateDirectories: true)
        } catch {
            throw ConfigError.invalidValue("Cannot create '\(path)': \(error.localizedDescription)")
        }
    } else {
        throw ConfigError.invalidValue("Directory does not exist: \(path)")
    }

    let probe = (path as NSString).appendingPathComponent(".clip2copy-write-test")
    guard fm.createFile(atPath: probe, contents: Data(), attributes: nil) else {
        throw ConfigError.notWritable(path)
    }
    try? fm.removeItem(atPath: probe)
    return path
}

func printUsage() {
    print("""
    clip2copy - auto-copy macOS screenshots to clipboard

    Usage:
      clip2copy <path-to.png>              Copy a PNG to the clipboard
      clip2copy setup                      Interactive setup wizard
      clip2copy config show                Show saved + system settings
      clip2copy config get <key>           Print one value (for scripts)
      clip2copy config set <key> <value>   Update one setting
      clip2copy config validate <key> <value>  Validate without saving
      clip2copy config apply               Re-apply macOS screenshot location
      clip2copy status                     Check config + service hints
      clip2copy --version
      clip2copy --help

    Config keys:
      location       desktop | downloads | /any/path
      rename         on | off
      prefix         optional prefix when rename on (Enter/none → a1b2c3.png)
      shadow         on | off   (drop shadow on screenshots)

    Notes:
      setup/config apply override macOS screenshot save location via
      com.apple.screencapture — same as System Settings > Screenshots.
      Default macOS location when unset: ~/Desktop

    Author: \(AUTHOR) (\(HOMEPAGE))
    Source: \(REPO)
    """)
}

func resolveLocationInput(_ input: String) throws -> String {
    try validateLocation(input, createIfMissing: true)
}

func renameLabel(_ config: Clip2CopyConfig) -> String {
    if config.rename {
        return "on (e.g. \(renameExample(config.renamePrefix)))"
    }
    return "off (keep macOS Screenshot….png)"
}

func cmdConfigValidate(_ key: String, _ value: String) throws {
    switch key {
    case "location":
        _ = try validateLocation(value, createIfMissing: true)
    case "prefix":
        _ = try validatePrefix(value)
    case "rename", "shadow":
        _ = try parseBool(value)
    default:
        throw ConfigError.invalidKey(key)
    }
}

func promptPrefix(default defaultValue: String) -> String {
    print("Filename prefix (e.g. ss → ss-a1b2c3.png) [Enter for none]: ", terminator: "")
    fflush(stdout)
    guard let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
        return defaultValue
    }
    return line
}

func prompt(_ message: String, default defaultValue: String) -> String {
    print("\(message) [\(defaultValue)]: ", terminator: "")
    fflush(stdout)
    guard let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
          !line.isEmpty else { return defaultValue }
    return line
}

func promptYesNo(_ message: String, default defaultYes: Bool) -> Bool {
    let hint = defaultYes ? "Y/n" : "y/N"
    let answer = prompt("\(message) (\(hint))", default: defaultYes ? "y" : "n")
        .lowercased()
    if answer == "y" || answer == "yes" { return true }
    if answer == "n" || answer == "no" { return false }
    return defaultYes
}

func isQuiet() -> Bool {
    ProcessInfo.processInfo.environment["CLIP2COPY_QUIET"] == "1"
}

func isNoApply() -> Bool {
    ProcessInfo.processInfo.environment["CLIP2COPY_NO_APPLY"] == "1"
}

func cmdSetupPlain() throws {
    let systemLoc = ScreenshotSettings.effectiveLocation()
    let existing = Clip2CopyConfig.load()

    print("""
    clip2copy setup
    ─────────────────────────────────────
    macOS currently saves screenshots to:
      \(systemLoc)

    clip2copy will set where screenshots land and watch that folder.
    """)

    print("""
    Choose screenshot save location:
      1) Downloads  (recommended)
      2) Desktop    (macOS factory default)
      3) Custom path
    """)
    let choice = prompt("Choice", default: "1")
    let location: String
    switch choice {
    case "2":
        location = try resolveLocationInput("desktop")
    case "3":
        while true {
            let candidate = prompt("Folder path", default: Clip2CopyConfig.defaultLocation())
            do {
                location = try resolveLocationInput(candidate)
                break
            } catch {
                print("🔴 \(error)")
            }
        }
    default:
        location = try resolveLocationInput("downloads")
    }

    print("""
    Rename screenshots to short random names?
      yes → e.g. a1b2c3.png  (or ss-a1b2c3.png with prefix "ss")
      no  → keep macOS name (Screenshot 2026-07-07 at 5.30.00 PM.png)
    """)
    let rename = promptYesNo("Rename screenshots", default: existing?.rename ?? true)
    var prefix = ""
    if rename {
        while true {
            let candidate = promptPrefix(default: prefix)
            do {
                prefix = try validatePrefix(candidate)
                break
            } catch {
                print("🔴 \(error)")
            }
        }
    }

    let shadow = promptYesNo("Drop window shadow on screenshots?", default: existing?.disableShadow ?? true)

    let config = Clip2CopyConfig(
        location: location,
        rename: rename,
        renamePrefix: prefix,
        disableShadow: shadow
    )
    try config.save()
    try ScreenshotSettings.apply(config: config)

    print("""
    🟢 clip2copy configured

      Save location : \(config.location)
      Rename files  : \(renameLabel(config))
      Drop shadow   : \(config.disableShadow ? "yes" : "no")
      Config file   : \(Clip2CopyConfig.configURL().path)

    Restart the watcher:
      brew services restart clip2copy
    """)
}

func cmdSetup() throws {
    try cmdSetupPlain()
}

func cmdConfigShow() {
    let config = Clip2CopyConfig.loadOrDefault()
    let hasConfig = Clip2CopyConfig.load() != nil
    print("clip2copy config")
    print("─────────────────────────────────────")
    print("Config file : \(Clip2CopyConfig.configURL().path)\(hasConfig ? "" : " (defaults — run setup)")")
    print("location    : \(config.location)")
    print("rename      : \(renameLabel(config))")
    print("prefix      : \(prefixDisplay(config.renamePrefix))")
    print("shadow off  : \(config.disableShadow)")
    print("")
    print("macOS screencapture")
    print("─────────────────────────────────────")
    print("location    : \(ScreenshotSettings.effectiveLocation())")
    if let shadow = ScreenshotSettings.disableShadowEnabled() {
        print("shadow off  : \(shadow)")
    } else {
        print("shadow off  : (system default)")
    }
}

func parseBool(_ value: String) throws -> Bool {
    switch value.lowercased() {
    case "1", "true", "yes", "on": return true
    case "0", "false", "no", "off": return false
    default: throw ConfigError.invalidValue("Expected on/off, got: \(value)")
    }
}

func cmdConfigGet(_ key: String) throws {
    let config = Clip2CopyConfig.loadOrDefault()
    switch key {
    case "location":
        print(config.location)
    case "rename":
        print(config.rename ? "1" : "0")
    case "shadow":
        print(config.disableShadow ? "1" : "0")
    case "prefix":
        print(config.renamePrefix)
    case "macos-location":
        print(ScreenshotSettings.effectiveLocation())
    case "config-path":
        print(Clip2CopyConfig.configURL().path)
    default:
        throw ConfigError.invalidKey(key)
    }
}

func cmdConfigSet(_ key: String, _ value: String) throws {
    var config = Clip2CopyConfig.loadOrDefault()
    switch key {
    case "location":
        config.location = try validateLocation(value, createIfMissing: true)
    case "rename":
        config.rename = try parseBool(value)
    case "prefix":
        config.renamePrefix = try validatePrefix(value)
    case "shadow":
        config.disableShadow = try parseBool(value)
    default:
        throw ConfigError.invalidKey(key)
    }
    if config.rename {
        config.renamePrefix = try validatePrefix(config.renamePrefix)
    }
    try config.save()
    if !isNoApply() {
        try ScreenshotSettings.apply(config: config)
    }
    if !isQuiet() {
        print("🟢 \(key) = \(value)")
        print("Restart watcher: brew services restart clip2copy")
    }
}

func cmdConfigApply() throws {
    let config = Clip2CopyConfig.loadOrDefault()
    try ScreenshotSettings.apply(config: config)
    print("🟢 Applied macOS screenshot location: \(config.location)")
    print("Restart watcher: brew services restart clip2copy")
}

func cmdStatus() {
    let config = Clip2CopyConfig.loadOrDefault()
    let systemLoc = ScreenshotSettings.effectiveLocation()
    let aligned = (expandPath(config.location) == expandPath(systemLoc))

    print("clip2copy status")
    print("─────────────────────────────────────")
    print("version     : \(VERSION)")
    print("watch dir   : \(config.location)")
    print("macOS saves : \(systemLoc)")
    print("in sync     : \(aligned ? "yes" : "no — run: clip2copy config apply")")
    print("rename      : \(renameLabel(config))")
    print("prefix      : \(prefixDisplay(config.renamePrefix))")
    print("config      : \(Clip2CopyConfig.configURL().path)")

    let svc = Shell.run("/bin/zsh", ["-lc", "brew services list 2>/dev/null | grep clip2copy || true"])
    if !svc.output.isEmpty {
        print("service     : \(svc.output)")
    } else {
        print("service     : (brew services not found or clip2copy not installed)")
    }
}

func cmdCopy(_ path: String) -> Int32 {
    let expanded = expandPath(path)
    guard let img = NSImage(contentsOfFile: expanded) else {
        fputs("failed\n", stderr)
        return 1
    }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects([img])
    print("copied")
    return 0
}

func main() -> Int32 {
    let args = Array(CommandLine.arguments.dropFirst())
    guard !args.isEmpty else {
        printUsage()
        return 1
    }

    switch args[0] {
    case "--help", "-h":
        printUsage()
        return 0
    case "--version", "-v":
        print("clip2copy \(VERSION)")
        print("Author: \(AUTHOR) (\(HOMEPAGE))")
        print("Source: \(REPO)")
        return 0
    case "setup":
        do { try cmdSetup() } catch {
            fputs("error: \(error)\n", stderr)
            return 1
        }
        return 0
    case "config":
        guard args.count >= 2 else {
            fputs("error: config requires a subcommand\n", stderr)
            return 1
        }
        do {
            switch args[1] {
            case "show":
                cmdConfigShow()
            case "get":
                guard args.count >= 3 else { throw ConfigError.missingArgument("config get <key>") }
                try cmdConfigGet(args[2])
            case "set":
                guard args.count >= 4 else { throw ConfigError.missingArgument("config set <key> <value>") }
                try cmdConfigSet(args[2], args[3])
            case "apply":
                try cmdConfigApply()
            case "validate":
                guard args.count >= 4 else { throw ConfigError.missingArgument("config validate <key> <value>") }
                try cmdConfigValidate(args[2], args[3])
            default:
                throw ConfigError.invalidKey(args[1])
            }
        } catch {
            fputs("error: \(error)\n", stderr)
            return 1
        }
        return 0
    case "status":
        cmdStatus()
        return 0
    default:
        if args[0].hasPrefix("-") {
            printUsage()
            return 1
        }
        return cmdCopy(args[0])
    }
}

exit(main())
