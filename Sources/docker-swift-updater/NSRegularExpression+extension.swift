//
//  NSRegularExpression+extension.swift
//  docker-swift-updater
//
//  Created by Norio Nomura on 4/25/18.
//

import Foundation

extension NSRegularExpression {
    func firstMatch(in string: String, options: MatchingOptions = []) -> NSTextCheckingResult? {
        return firstMatch(in: string, options: options, range: NSRange(string.startIndex..<string.endIndex, in: string))
    }

    func firstMatchRanges(in string: String, options: MatchingOptions = []) -> [Range<String.Index>]? {
        guard let result = firstMatch(in: string, options: options) else { return nil }
        return (0..<result.numberOfRanges).compactMap {
            return Range.init(result.range(at: $0), in: string)
        }
    }
}
