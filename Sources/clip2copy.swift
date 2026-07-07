import Cocoa
import Foundation

/// clip2copy - auto-copy macOS screenshots to clipboard
/// Author: vdutts7 (https://vd7.io)
/// Source: https://github.com/vdutts7/clip2copy
/// License: MIT

let VERSION = "1.1.1"
let AUTHOR = "vdutts7"
let HOMEPAGE = "https://vd7.io"
let REPO = "https://github.com/vdutts7/clip2copy"

struct Clip2CopyConfig: Codable {
    var location: String
    var rename: Bool
    var disableShadow: Bool

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
        let location = expandPath(config.location)
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: location, isDirectory: &isDir) {
            try FileManager.default.createDirectory(atPath: location, withIntermediateDirectories: true)
        } else if !isDir.boolValue {
            throw ConfigError.notADirectory(location)
        }

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
    case invalidKey(String)
    case invalidValue(String)
    case missingArgument(String)

    var description: String {
        switch self {
        case .notADirectory(let path): return "Not a directory: \(path)"
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

func printUsage() {
    print("""
    clip2copy - auto-copy macOS screenshots to clipboard

    Usage:
      clip2copy <path-to.png>              Copy a PNG to the clipboard
      clip2copy setup                      Interactive setup wizard
      clip2copy config show                Show saved + system settings
      clip2copy config get <key>           Print one value (for scripts)
      clip2copy config set <key> <value>   Update one setting
      clip2copy config apply               Re-apply macOS screenshot location
      clip2copy status                     Check config + service hints
      clip2copy --version
      clip2copy --help

    Config keys:
      location       desktop | downloads | /any/path
      rename         on | off
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
    let path = expandPath(input)
    var isDir: ObjCBool = false
    if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
        guard isDir.boolValue else { throw ConfigError.notADirectory(path) }
        return path
    }
    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    return path
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

func locateSetupScript() -> String? {
    let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
    let candidates = [
        exe.deletingLastPathComponent().appendingPathComponent("../libexec/clip2copy-setup.sh"),
        exe.deletingLastPathComponent().appendingPathComponent("../scripts/clip2copy-setup.sh"),
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("scripts/clip2copy-setup.sh"),
    ]
    for url in candidates {
        let path = url.standardized.path
        if FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
    }
    return nil
}

func isQuiet() -> Bool {
    ProcessInfo.processInfo.environment["CLIP2COPY_QUIET"] == "1"
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
        location = try resolveLocationInput(prompt("Folder path", default: Clip2CopyConfig.defaultLocation()))
    default:
        location = try resolveLocationInput("downloads")
    }

    let rename = promptYesNo("Rename screenshots to ss-<random>.png?", default: existing?.rename ?? true)
    let shadow = promptYesNo("Drop window shadow on screenshots?", default: existing?.disableShadow ?? true)

    let config = Clip2CopyConfig(
        location: location,
        rename: rename,
        disableShadow: shadow
    )
    try config.save()
    try ScreenshotSettings.apply(config: config)

    print("""
    🟢 clip2copy configured

      Save location : \(config.location)
      Rename files  : \(config.rename ? "yes" : "no")
      Drop shadow   : \(config.disableShadow ? "yes" : "no")
      Config file   : \(Clip2CopyConfig.configURL().path)

    Restart the watcher:
      brew services restart clip2copy
    """)
}

func cmdSetup() throws {
    if CommandLine.arguments.contains("--plain") {
        try cmdSetupPlain()
        return
    }
    guard let script = locateSetupScript() else {
        try cmdSetupPlain()
        return
    }
    var env = ProcessInfo.processInfo.environment
    env["CLIP2COPY_BIN"] = CommandLine.arguments[0]
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = [script]
    process.environment = env
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
        throw ConfigError.invalidValue("setup failed")
    }
}

func cmdConfigShow() {
    let config = Clip2CopyConfig.loadOrDefault()
    let hasConfig = Clip2CopyConfig.load() != nil
    print("clip2copy config")
    print("─────────────────────────────────────")
    print("Config file : \(Clip2CopyConfig.configURL().path)\(hasConfig ? "" : " (defaults — run setup)")")
    print("location    : \(config.location)")
    print("rename      : \(config.rename)")
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
        config.location = try resolveLocationInput(value)
    case "rename":
        config.rename = try parseBool(value)
    case "shadow":
        config.disableShadow = try parseBool(value)
    default:
        throw ConfigError.invalidKey(key)
    }
    try config.save()
    try ScreenshotSettings.apply(config: config)
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
    print("rename      : \(config.rename ? "on" : "off")")
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
