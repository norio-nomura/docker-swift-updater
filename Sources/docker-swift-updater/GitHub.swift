//
//  GitHub.swift
//  docker-swift-updater
//
//  Created by Norio Nomura on 4/25/18.
//

import Foundation

#if os(macOS) || os(Linux) && swift(>=4.1)
let session = URLSession.shared
#else
let session = URLSession(configuration: .default)
#endif

struct GitHub {
    static let token: String = {
        guard let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] else {
            fatalError("Missing `GITHUB_TOKEN` environment variable!")
        }
        return token
    }()

    static func repository(owner: String, name: String) -> Repository {
        return .init(owner: owner, name: name)
    }

    static let graphQLURL = URL(string: "https://api.github.com/graphql")!
}

struct Repository {
    let owner: String
    let name: String

    init(owner: String, name: String) {
        self.owner = owner
        self.name = name
    }

    var tags: AnySequence<String> {
        return AnySequence { () -> AnyIterator<String> in
            var connection = QueryForTags(in: self).fetch()
            var hasNextPage = connection?.pageInfo.hasNextPage ?? false
            var tags = ArraySlice(connection?.tags ?? [])
            return AnyIterator { () -> String? in
                guard let name = tags.popFirst()?.name else {
                    guard hasNextPage, let pageInfo = connection?.pageInfo else { return nil }
                    connection = QueryForTags(in: self, after: pageInfo.endCursor).fetch()
                    hasNextPage = connection?.pageInfo.hasNextPage ?? false
                    tags = ArraySlice(connection?.tags ?? [])
                    return tags.popFirst()?.name
                }
                return name
            }
        }
    }

    private struct QueryForTags: Encodable {
        let query: String
        let variables: String

        init(in repository: Repository, after cursor: String = "") {
            query = """
            query($owner:String!, $name:String!, $cursor:String = "") {
                repository(owner: $owner, name: $name) {
                    refs(refPrefix: "refs/tags/", first: 100, after: $cursor, orderBy: {field: TAG_COMMIT_DATE, direction: DESC}) {
                        pageInfo {
                            endCursor
                            hasNextPage
                            startCursor
                        }
                        tags: nodes {
                            name
                        }
                    }
                }
            }
            """
            variables = """
            {
                "owner": "\(repository.owner)",
                "name": "\(repository.name)",
                "cursor": "\(cursor)"
            }
            """
        }

        var request: URLRequest {
            var request = URLRequest(url: GitHub.graphQLURL)
            request.httpMethod = "POST"
            request.setValue("bearer \(GitHub.token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try! JSONEncoder().encode(self)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            return request
        }

        func fetch() -> Payload.RefConnection? {
            let semaphore = DispatchSemaphore(value: 0)
            var connection: Payload.RefConnection?
            let task = session.dataTask(with: request) { data, response, error in
                defer { semaphore.signal() }
                if let error = error {
                    fatalError("failed with error: \(error)")
                }
                guard let httpURLResponse = response as? HTTPURLResponse else {
                    fatalError("unknown response: \(String(describing: response))")
                }
                guard (200...299).contains(httpURLResponse.statusCode) else {
                    fatalError("server error status: \(httpURLResponse.statusCode)")
                }
                guard let data = data else {
                    fatalError("failed to unwrap data returned from \(GitHub.graphQLURL)")
                }
                do {
                    let payload = try JSONDecoder().decode(Payload.self, from: data)
                    connection = payload.data.repository.refs
                } catch {
                    fatalError("failed to decode payload with error: \(error)")
                }
            }
            task.resume()
            semaphore.wait()
            return connection
        }
    }

    private struct Payload: Decodable {
        let data: Data

        struct Data: Decodable { let repository: Repository }
        struct Repository: Decodable { let refs: RefConnection }
        struct RefConnection: Decodable { let pageInfo: PageInfo, tags: [Ref] }
        struct PageInfo: Decodable { let endCursor: String, hasNextPage: Bool, startCursor: String }
        struct Ref: Decodable { let name: String }
    }
}
