//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
#if swift(>=5.9)
@_spi(AsyncChannel) import NIOCore
@_spi(AsyncChannel) import NIOPosix

@available(macOS 14, *)
@main
struct Server {
    /// The server's host.
    private let host: String
    /// The server's port.
    private let port: Int
    /// The server's event loop group.
    private let eventLoopGroup: MultiThreadedEventLoopGroup

    static func main() async throws {
        let server = Server(
            host: "localhost",
            port: 8765,
            eventLoopGroup: .singleton
        )
        try await server.run()
    }

    /// This method starts the server and handles incoming connections.
    func run() async throws {
        let channel = try await ServerBootstrap(group: self.eventLoopGroup)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .bind(
                host: self.host,
                port: self.port
            ) { channel in
                channel.eventLoop.makeCompletedFuture {
                    // We are using two simple handlers here to frame our messages with "\n"
                    try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(NewlineDelimiterCoder()))
                    try channel.pipeline.syncOperations.addHandler(MessageToByteHandler(NewlineDelimiterCoder()))

                    return try NIOAsyncChannel(
                        synchronouslyWrapping: channel,
                        configuration: .init(
                            inboundType: String.self,
                            outboundType: String.self
                        )
                    )
                }
            }

        // We are handling each incoming connection in a separate child task. It is important
        // to use a discarding task group here which automatically discards finished child tasks.
        // A normal task group retains all child tasks and their outputs in memory until they are
        // consumed by iterating the group or by exiting the group. Since, we are never consuming
        // the results of the group we need the group to automatically discard them; otherwise, this
        // would result in a memory leak over time.
        try await withThrowingDiscardingTaskGroup { group in
            for try await connectionChannel in channel.inboundStream {
                group.addTask {
                    print("Handling new connection")
                    await self.handleConnection(channel: connectionChannel)
                    print("Done handling connection")
                }
            }
        }
    }

    /// This method handles a single connection by echoing back all inbound data.
    private func handleConnection(channel: NIOAsyncChannel<String, String>) async {
        // Note that this method is non-throwing and we are catching any error.
        // We do this since we don't want to tear down the whole server when a single connection
        // encounters an error.
        do {
            for try await inboundData in channel.inboundStream {
                print("Received request (\(inboundData))")
                try await channel.outboundWriter.write(inboundData)
            }
        } catch {
            print("Hit error: \(error)")
        }
    }
}


/// A simple newline based encoder and decoder.
private final class NewlineDelimiterCoder: ByteToMessageDecoder, MessageToByteEncoder {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = String

    private let newLine = UInt8(ascii: "\n")

    init() {}

    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        let readable = buffer.withUnsafeReadableBytes { $0.firstIndex(of: self.newLine) }
        if let readable = readable {
            context.fireChannelRead(self.wrapInboundOut(buffer.readString(length: readable)!))
            buffer.moveReaderIndex(forwardBy: 1)
            return .continue
        }
        return .needMoreData
    }

    func encode(data: String, out: inout ByteBuffer) throws {
        out.writeString(data)
        out.writeString("\n")
    }
}
#else
@main
struct Server {
    static func main() {
        fatalError("Requires at least Swift 5.9")
    }
}
#endif
