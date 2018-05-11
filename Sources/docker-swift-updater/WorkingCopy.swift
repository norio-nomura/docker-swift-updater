//
//  WorkingCopy.swift
//  docker-swift-updater
//
//  Created by Norio Nomura on 4/25/18.
//

import Foundation

struct WorkingCopy {
    let url: URL

    init(_ path: String) {
        url = URL(fileURLWithPath: path)
    }

    func add(_ file: String) throws {
        try execute(["git", "add", file], at: url)
    }

    func checkout(_ branch: String) throws {
        try execute(["git", "checkout", branch], at: url)
    }

    func commit(message: String, tag: String = "", all: Bool = false) throws {
        let preCommitHash = try hash()
        let command = ["git", "commit"] + (all ? ["--all"] : []) + ["--message", message]
        try execute(command, at: url)
        guard try hash() != preCommitHash else {
            throw Error.failed(subcommand: command.joined(separator: " "), message: "failed to commit", status: 0)
        }
        if !tag.isEmpty {
            try execute(["git", "tag", "--annotate", "--message", "", tag], at: url)
        }
    }

    func dockerfile(in branch: String = "") throws -> Dockerfile {
        if !branch.isEmpty {
            try checkout(branch)
        }
        return try .init(url: url.appendingPathComponent("Dockerfile"))
    }

    func hash() throws -> String {
        return try execute(["git", "rev-parse", "HEAD"], at: url)
    }

    func push() throws {
        try execute(["git", "push"], at: url)
    }

    func pushTags() throws {
        try execute(["git", "push", "--tags"], at: url)
    }

    func resetHard() throws {
        try execute(["git", "reset", "--hard"], at: url)
    }

    func tags(in branch: String = "") throws -> [String] {
        try execute(["git", "fetch", "--tags"], at: url)
        if branch.isEmpty {
            return try execute(["git", "tag", "--sort", "taggerdate"], at: url)
                .components(separatedBy: .newlines)
        } else {
            return try execute(["git", "tag", "--sort", "taggerdate", "--merged", "origin/\(branch)"], at: url)
                .components(separatedBy: .newlines)
        }
    }
}
