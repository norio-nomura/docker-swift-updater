//
//  Dockerfile.swift
//  docker-swift-updater
//
//  Created by Norio Nomura on 4/25/18.
//

import Foundation

struct Dockerfile {
    var contents: String
    let url: URL

    init(url: URL) throws {
        self.url = url
        contents = try String(contentsOf: url)
    }

    private static let branchRegex = try! NSRegularExpression(pattern: "^ENV\\s*SWIFT_BRANCH=(\\S*)", options: .anchorsMatchLines)
    private static let versionRegex = try! NSRegularExpression(pattern: "^\\s*SWIFT_VERSION=(\\S*)", options: .anchorsMatchLines)
    private static let versionPrefix = "swift-"

    func dockerfile(branch: String, version: String) throws -> Dockerfile {
        var dockerfile = self
        let branchRange = try dockerfile.rangeOfBranch()
        if version.hasSuffix("-RELEASE") {
            let branch = branch.isEmpty ? version.lowercased() : branch
            dockerfile.contents.replaceSubrange(branchRange, with: branch)
        }
        let versionRange = try dockerfile.rangeOfVersion()
        if version.hasPrefix(Dockerfile.versionPrefix) {
            dockerfile.contents.replaceSubrange(versionRange, with: version.dropFirst(Dockerfile.versionPrefix.count))
        } else {
            dockerfile.contents.replaceSubrange(versionRange, with: version)
        }
        return dockerfile
    }

    func getBranch() throws -> String {
        let range = try rangeOfBranch()
        return String(contents[range])
    }

    func getSwiftVersion() throws -> String {
        let range = try rangeOfVersion()
        return Dockerfile.versionPrefix + contents[range]
    }

    func rangeOfBranch() throws -> Range<String.Index> {
        guard let range = Dockerfile.branchRegex.firstMatchRanges(in: contents)?[1] else {
            throw Error.swiftBranchNotFound
        }
        return range
    }

    func rangeOfVersion() throws -> Range<String.Index> {
        guard let range = Dockerfile.versionRegex.firstMatchRanges(in: contents)?[1] else {
            throw Error.swiftVersionNotFound
        }
        return range
    }

    func write() throws {
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    enum Error: CustomStringConvertible, Swift.Error {
        case swiftBranchNotFound
        case swiftVersionNotFound
        var description: String {
            switch self {
            case .swiftBranchNotFound:
                return "`SWIFT_BRANCH` not found!"
            case .swiftVersionNotFound:
                return "`SWIFT_VERSION` not found!"
            }
        }
    }
}
