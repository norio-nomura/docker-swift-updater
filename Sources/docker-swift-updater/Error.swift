//
//  Error.swift
//  docker-swift-updater
//
//  Created by Norio Nomura on 4/25/18.
//

enum Error: CustomStringConvertible, Swift.Error {
    case failed(subcommand: String, message: String, status: Int32)
    case swiftBranchNotFound
    case swiftVersionNotFound
    var description: String {
        switch self {
        case let .failed(subcommand: subcommand, message: message, status: status):
            return "`\(subcommand)` failed with status: \(status)\n\(message)"
        case .swiftBranchNotFound:
            return "`SWIFT_BRANCH` not found!"
        case .swiftVersionNotFound:
            return "`SWIFT_VERSION` not found!"
        }
    }
}
