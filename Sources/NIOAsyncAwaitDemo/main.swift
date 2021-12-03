//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import NIOCore
import NIOPosix
import NIOHTTP1
import Dispatch

#if canImport(_Concurrency) && compiler(>=5.5.2) || (!os(macOS) && compiler(>=5.5))

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
func makeHTTPChannel(host: String, port: Int, group: EventLoopGroup) async throws -> AsyncChannelIO<HTTPRequestHead, NIOHTTPClientResponseFull> {
    let channel = try await ClientBootstrap(group: group).connect(host: host, port: port).get()
    try await channel.pipeline.addHTTPClientHandlers().get()
    try await channel.pipeline.addHandler(NIOHTTPClientResponseAggregator(maxContentLength: 1_000_000))
    try await channel.pipeline.addHandler(MakeFullRequestHandler())
    return try await AsyncChannelIO<HTTPRequestHead, NIOHTTPClientResponseFull>(channel).start()
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
func main() async {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    do {
        let channel = try await makeHTTPChannel(host: "httpbin.org", port: 80, group: group)
        print("OK, connected to \(channel)")

        print("Sending request 1", terminator: "")
        let response1 = try await channel.sendRequest(HTTPRequestHead(version: .http1_1,
                                                                     method: .GET,
                                                                     uri: "/base64/SGVsbG8gV29ybGQsIGZyb20gSFRUUEJpbiEgCg==",
                                                                     headers: ["host": "httpbin.org"]))
        print(", response:", String(buffer: response1.body ?? ByteBuffer()))

        print("Sending request 2", terminator: "")
        let response2 = try await channel.sendRequest(HTTPRequestHead(version: .http1_1,
                                                                     method: .GET,
                                                                     uri: "/get",
                                                                     headers: ["host": "httpbin.org"]))
        print(", response:", String(buffer: response2.body ?? ByteBuffer()))

        try await channel.close()

        print("Shutting down event loop group...")
        try await group.shutdownGracefully()

        print("all, done")
    } catch {
        print("ERROR: \(error)")
        print("Shutting down event loop group (possibly for a second time)...")
        do {
            try await group.shutdownGracefully()
        } catch {
            print("Error shutting down event loop group: \(error)")
        }
    }
}

let dg = DispatchGroup()
dg.enter()
if #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) {
    Task {
        await main()
        dg.leave()
    }
} else {
    dg.leave()
}
dg.wait()
#else
print("ERROR: The NIO Async Await Demo supports Swift >= 5.5.2 (>= Xcode 13.2) on macOS 10.15 and newer, or Swift >= 5.5 on other platforms.")
#endif
