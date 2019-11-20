//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO

/// Implements a simple chat protocol.
private final class ChatMessageDecoder: ChannelInboundHandler {
    public typealias InboundIn = AddressedEnvelope<ByteBuffer>

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let envelope = self.unwrapInboundIn(data)
        var buffer = envelope.data

        // To begin with, the chat messages are simply whole datagrams, no other length.
        guard let message = buffer.readString(length: buffer.readableBytes) else {
            print("Error: invalid string received")
            return
        }

        print("\(envelope.remoteAddress): \(message)")
    }
}


private final class ChatMessageEncoder: ChannelOutboundHandler {
    public typealias OutboundIn = AddressedEnvelope<String>
    public typealias OutboundOut = AddressedEnvelope<ByteBuffer>

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let message = self.unwrapOutboundIn(data)
        var buffer = context.channel.allocator.buffer(capacity: message.data.utf8.count)
        buffer.writeString(message.data)
        context.write(self.wrapOutboundOut(AddressedEnvelope(remoteAddress: message.remoteAddress, data: buffer)), promise: promise)
    }
}


// We allow users to specify the interface they want to use here.
var targetInterface: NIONetworkInterface? = nil
if let interfaceAddress = CommandLine.arguments.dropFirst().first,
   let targetAddress = try? SocketAddress(ipAddress: interfaceAddress, port: 0) {
    for interface in try! System.enumerateInterfaces() {
        if interface.address == targetAddress {
            targetInterface = interface
            break
        }
    }

    if targetInterface == nil {
        fatalError("Could not find interface for \(interfaceAddress)")
    }
}

// For this chat protocol we temporarily squat on 224.1.0.26. This is a reserved multicast IPv4 address,
// so your machine is unlikely to have already joined this group. That helps properly demonstrate correct
// operation. We use port 7654 because, well, because why not.
let chatMulticastGroup = try! SocketAddress(ipAddress: "224.1.0.26", port: 7654)
let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

// Begin by setting up the basics of the bootstrap.
var datagramBootstrap = DatagramBootstrap(group: group)
    .channelOption(ChannelOptions.Types.SocketOption.other(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
    .channelOption(ChannelOptions.Types.SocketOption.other(SocketOptionLevel(SOL_SOCKET), SO_REUSEPORT), value: 1)
    .channelInitializer { channel in
        return channel.pipeline.addHandler(ChatMessageEncoder()).flatMap {
            channel.pipeline.addHandler(ChatMessageDecoder())
        }
    }

    // We cast our channel to MulticastChannel to obtain the multicast operations.
let datagramChannel = try datagramBootstrap
    .bind(host: "0.0.0.0", port: 7654)
    .flatMap { channel -> EventLoopFuture<Channel> in
        let channel = channel as! MulticastChannel
        return channel.joinGroup(chatMulticastGroup, interface: targetInterface).map { channel }
    }.flatMap { channel -> EventLoopFuture<Channel> in
        guard let targetInterface = targetInterface else {
            return channel.eventLoop.makeSucceededFuture(channel)
        }

        let provider = channel as! SocketOptionProvider
        switch targetInterface.address {
        case .v4(let addr):
            return provider.setIPMulticastIF(addr.address.sin_addr).map { channel }
        case .v6:
            return provider.setIPv6MulticastIF(CUnsignedInt(targetInterface.interfaceIndex)).map { channel }
        case .unixDomainSocket:
            preconditionFailure("Should not be possible to create a multicast socket on a unix domain socket")
        }
    }.wait()

print("Now broadcasting, happy chatting.\nPress ^D to exit.")

while let line = readLine(strippingNewline: false) {
    datagramChannel.writeAndFlush(AddressedEnvelope(remoteAddress: chatMulticastGroup, data: line), promise: nil)
}

// Close the channel.
try! datagramChannel.close().wait()
try! group.syncShutdownGracefully()
