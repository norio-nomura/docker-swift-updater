import Foundation
import SwiftBacktrace

let signalHandler: @convention(c) (Int32) -> Swift.Void = { signo in
    print(demangledBacktrace().joined(separator: "\n"))
    exit(128 + signo)
}

let verbose = UserDefaults.standard.bool(forKey: "Verbose")
// deadly signals
signal(SIGSEGV, signalHandler)
signal(SIGBUS, signalHandler)
signal(SIGABRT, signalHandler)
signal(SIGFPE, signalHandler)
signal(SIGILL, signalHandler)
// EXC_BAD_INSTRUCTION
signal(SIGUSR1, signalHandler)

// range[0] entier content
// range[1] prefix
// range[2..] version identifiers
let swiftVersionPrefixPatterns = [
    "(swift-DEVELOPMENT-SNAPSHOT-)(.*)$",
    "(swift-([\\.\\d]+)-DEVELOPMENT-SNAPSHOT-)(.*)$"
].map { try! NSRegularExpression(pattern: $0, options: .anchorsMatchLines) }
// range[0] entire content
// range[1] version identifier
// range[2] suffix
let swiftVersionSuffixPatterns = [
    "swift-([\\.\\d]+)(-RELEASE)$",
].map { try! NSRegularExpression(pattern: $0, options: .anchorsMatchLines) }

do {
    let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let workingCopy = WorkingCopy(currentDirectoryURL.path)
    let dockerfile = try workingCopy.dockerfile()
    let currentSwiftVersion = try dockerfile.getSwiftVersion()
    print("Current Swift version: \(currentSwiftVersion)")
    var tagAndIdentifiers = [(tag: String, identifier: String)]()
    var branch: String?
    let repository = GitHub.repository(owner: "apple", name: "swift")
    // Check Swift version prefix patterns
    let prefixAndPatterns = swiftVersionPrefixPatterns.compactMap { pattern -> (String, NSRegularExpression)? in
        guard let range = pattern.firstMatchRanges(in: currentSwiftVersion)?[1] else { return nil }
        return (String(currentSwiftVersion[..<range.upperBound]), pattern)
    }
    for (prefix, pattern) in prefixAndPatterns {
        for tag in repository.tags where tag.hasPrefix(prefix) {
            guard tag != currentSwiftVersion else { break }
            guard let identifier = pattern.firstMatchRanges(in: tag)?[2...].map({ tag[$0] })
                .joined().unicodeScalars.filter(CharacterSet.alphanumerics.contains) else { continue }
            tagAndIdentifiers.append((tag, String(identifier)))
        }
        branch = try dockerfile.getBranch()
    }

    if tagAndIdentifiers.isEmpty {
        // Check Swift version suffix patterns
        let suffixAndPetterns = swiftVersionSuffixPatterns.compactMap { pattern -> (String, NSRegularExpression)? in
            guard let range = pattern.firstMatchRanges(in: currentSwiftVersion)?[2] else { return nil }
            return (String(currentSwiftVersion[range.lowerBound...]), pattern)
        }

        for (suffix, pattern) in suffixAndPetterns {
            for tag in repository.tags where tag.hasSuffix(suffix) {
                guard tag != currentSwiftVersion else { break }
                guard let range = pattern.firstMatchRanges(in: tag)?[1] else { continue }
                let identifier = tag[range].unicodeScalars.filter(CharacterSet.alphanumerics.contains)
                tagAndIdentifiers.append((tag, String(identifier)))
            }
        }
    }

    if tagAndIdentifiers.isEmpty {
        fatalError("unknown swift version string: \(currentSwiftVersion)")
    }
    print("Found tags: \(tagAndIdentifiers)")
    for (tag, identifier) in tagAndIdentifiers.sorted(by: { $0.tag < $1.tag }) {
        let updatedDockerfile = try dockerfile.dockerfile(branch: branch ?? tag.lowercased(), version: tag)
        try execute(["docker", "build", "-", "--tag", "updater", "--force-rm"],
                    at: currentDirectoryURL,
                    input: updatedDockerfile.contents.data(using: .utf8),
                    verbose: verbose)
        try updatedDockerfile.write()
        try workingCopy.add(dockerfile.url.path)
        try workingCopy.commit(message: tag, tag: identifier)
        try workingCopy.pushTags()
    }
} catch {
    fatalError("\(error)")
}
