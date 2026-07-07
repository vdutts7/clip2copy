import Cocoa

/// clip2copy - copy macOS screenshot PNGs to clipboard via NSPasteboard
/// Author: vdutts7 (https://vd7.io)
/// Source: https://github.com/vdutts7/clip2copy
/// License: MIT

let VERSION = "1.0.0"
let AUTHOR = "vdutts7"
let HOMEPAGE = "https://vd7.io"
let REPO = "https://github.com/vdutts7/clip2copy"

func printUsage() {
    fputs("""
    clip2copy - copy a PNG image to the macOS clipboard

    Usage:
      clip2copy <path-to.png>
      clip2copy --version
      clip2copy --help

    Notes:
      Uses NSImage + NSPasteboard (works on macOS Sequoia 15+).
      Typically invoked by clip2copy-watch after a screenshot is saved.

    Author: \(AUTHOR) (\(HOMEPAGE))
    Source: \(REPO)

    """, stderr)
}

guard CommandLine.arguments.count > 1 else {
    printUsage()
    exit(1)
}

switch CommandLine.arguments[1] {
case "--help", "-h":
    printUsage()
    exit(0)
case "--version", "-v":
    print("clip2copy \(VERSION)")
    print("Author: \(AUTHOR) (\(HOMEPAGE))")
    print("Source: \(REPO)")
    exit(0)
default:
    break
}

let path = CommandLine.arguments[1]
guard let img = NSImage(contentsOfFile: path) else {
    fputs("failed\n", stderr)
    exit(1)
}

NSPasteboard.general.clearContents()
NSPasteboard.general.writeObjects([img])
print("copied")
