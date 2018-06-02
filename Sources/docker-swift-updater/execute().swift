//
//  execute().swift
//  docker-swift-updater
//
//  Created by Norio Nomura on 4/25/18.
//

import Dispatch
import Foundation

private final class Pipe {
    let fileHandleForReading: FileHandle
    let fileHandleForWriting: FileHandle

    typealias ReadabilityHandler = (Data) -> Void
    let readabilityHandler: ReadabilityHandler?

    init(readabilityHandler: ReadabilityHandler? = nil) throws {
        var fileDescriptors: [Int32] = [0, 0]
        guard 0 == pipe(&fileDescriptors) else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        fileHandleForReading = .init(fileDescriptor: fileDescriptors[0], closeOnDealloc: true)
        fileHandleForWriting = .init(fileDescriptor: fileDescriptors[1], closeOnDealloc: true)

        self.readabilityHandler = readabilityHandler
    }

    func readOutput() -> Data {
        fileHandleForWriting.closeFile()
        let size = 4096
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { buffer.deallocate() }
        while true {
            let n = read(fileHandleForReading.fileDescriptor, buffer, size)
            guard n > 0 else { return data }
            let newData = Data(bytes: buffer, count: n)
            data.append(newData)
            readabilityHandler?(newData)
        }
    }
}

@discardableResult
func execute(_ arguments: [String],
             at url: URL? = nil,
             environment: [String: String]? = nil,
             input: Data? = nil,
             verbose: Bool = true) throws -> String {
    if verbose {
        print("- " + arguments.joined(separator: " "))
    }
    let process = Process()
    process.launchPath = "/usr/bin/env"
    process.arguments = arguments
    if let url = url {
        process.currentDirectoryPath = url.path
    }
    process.environment = ProcessInfo.processInfo.environment
    process.environment?["PAGER"] = nil
    if let environment = environment {
        process.environment = process.environment?.merging(environment) {
            (_, new) in new
        }
    }

    let stdoutPipe = try Pipe(readabilityHandler: verbose ? FileHandle.standardOutput.write : nil)
    let stderrPipe = try Pipe(readabilityHandler: FileHandle.standardError.write)

    process.standardOutput = stdoutPipe.fileHandleForWriting
    process.standardError = stderrPipe.fileHandleForWriting
    if let input = input {
        let stdinPipe = try Pipe()
        process.standardInput = stdinPipe.fileHandleForReading
        stdinPipe.fileHandleForWriting.write(input)
        stdinPipe.fileHandleForWriting.closeFile()
    }
    process.launch()
    let group = DispatchGroup()
    var stdoutData = Data()
    DispatchQueue.global().async(group: group) { stdoutData.append(stdoutPipe.readOutput()) }
    var stderrData = Data()
    DispatchQueue.global().async(group: group) { stderrData.append(stderrPipe.readOutput()) }
    process.waitUntilExit()
    group.wait()

    if process.terminationStatus != 0 {
        throw Error.failed(subcommand: arguments.joined(separator: " "),
                           message: String(data: stderrData, encoding: .utf8) ?? "",
                           status: process.terminationStatus)
    }

    return String(data: stdoutData, encoding: .utf8) ?? ""
}
