//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2022 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import NIOCore

/// A `RawSocketBootstrap` is an easy way to interact with IP based protocols other then TCP and UDP.
///
/// Example:
///
/// ```swift
///     let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
///     defer {
///         try! group.syncShutdownGracefully()
///     }
///     let bootstrap = RawSocketBootstrap(group: group)
///         .channelInitializer { channel in
///             channel.pipeline.addHandler(MyChannelHandler())
///         }
///     let channel = try! bootstrap.bind(host: "127.0.0.1", ipProtocol: .icmp).wait()
///     /* the Channel is now ready to send/receive IP packets */
///
///     try channel.closeFuture.wait()  // Wait until the channel un-binds.
/// ```
///
/// The `Channel` will operate on `AddressedEnvelope<ByteBuffer>` as inbound and outbound messages.
public final class RawSocketBootstrap {

    private let group: EventLoopGroup
    private var channelInitializer: Optional<ChannelInitializerCallback>
    @usableFromInline
    internal var _channelOptions: ChannelOptions.Storage

    /// Create a `RawSocketBootstrap` on the `EventLoopGroup` `group`.
    ///
    /// The `EventLoopGroup` `group` must be compatible, otherwise the program will crash. `RawSocketBootstrap` is
    /// compatible only with `MultiThreadedEventLoopGroup` as well as the `EventLoop`s returned by
    /// `MultiThreadedEventLoopGroup.next`. See `init(validatingGroup:)` for a fallible initializer for
    /// situations where it's impossible to tell ahead of time if the `EventLoopGroup` is compatible or not.
    ///
    /// - parameters:
    ///     - group: The `EventLoopGroup` to use.
    public convenience init(group: EventLoopGroup) {
        guard NIOOnSocketsBootstraps.isCompatible(group: group) else {
            preconditionFailure("RawSocketBootstrap is only compatible with MultiThreadedEventLoopGroup and " +
                                "SelectableEventLoop. You tried constructing one with \(group) which is incompatible.")
        }
        self.init(validatingGroup: group)!
    }

    /// Create a `RawSocketBootstrap` on the `EventLoopGroup` `group`, validating that `group` is compatible.
    ///
    /// - parameters:
    ///     - group: The `EventLoopGroup` to use.
    public init?(validatingGroup group: EventLoopGroup) {
        guard NIOOnSocketsBootstraps.isCompatible(group: group) else {
            return nil
        }
        self._channelOptions = ChannelOptions.Storage()
        self.group = group
        self.channelInitializer = nil
    }
    
    /// Initialize the bound `Channel` with `initializer`. The most common task in initializer is to add
    /// `ChannelHandler`s to the `ChannelPipeline`.
    ///
    /// - parameters:
    ///     - handler: A closure that initializes the provided `Channel`.
    public func channelInitializer(_ handler: @escaping @Sendable (Channel) -> EventLoopFuture<Void>) -> Self {
        self.channelInitializer = handler
        return self
    }

    /// Specifies a `ChannelOption` to be applied to the `Channel`.
    ///
    /// - parameters:
    ///     - option: The option to be applied.
    ///     - value: The value for the option.
    @inlinable
    public func channelOption<Option: ChannelOption>(_ option: Option, value: Option.Value) -> Self {
        self._channelOptions.append(key: option, value: value)
        return self
    }

    /// Bind the `Channel` to `host`.
    /// All packets or errors matching the `ipProtocol` specified are passed to the resulting `Channel`.
    ///
    /// - parameters:
    ///     - host: The host to bind on.
    ///     - ipProtocol: The IP protocol used in the IP protocol/nextHeader field.
    public func bind(host: String, ipProtocol: NIOIPProtocol) -> EventLoopFuture<Channel> {
        return bind0(ipProtocol: ipProtocol) {
            return try SocketAddress.makeAddressResolvingHost(host, port: 0)
        }
    }

    private func bind0(ipProtocol: NIOIPProtocol, _ makeSocketAddress: () throws -> SocketAddress) -> EventLoopFuture<Channel> {
        let address: SocketAddress
        do {
            address = try makeSocketAddress()
        } catch {
            return group.next().makeFailedFuture(error)
        }
        precondition(address.port == nil || address.port == 0, "port must be 0 or not set")
        func makeChannel(_ eventLoop: SelectableEventLoop) throws -> DatagramChannel {
            return try DatagramChannel(eventLoop: eventLoop,
                                       protocolFamily: address.protocol,
                                       protocolSubtype: .init(ipProtocol),
                                       socketType: .raw)
        }
        return withNewChannel(makeChannel: makeChannel) { (eventLoop, channel) in
            channel.register().flatMap {
                channel.bind(to: address)
            }
        }
    }

    /// Connect the `Channel` to `host`.
    ///
    /// - parameters:
    ///     - host: The host to connect to.
    ///     - ipProtocol: The IP protocol used in the IP protocol/nextHeader field.
    public func connect(host: String, ipProtocol: NIOIPProtocol) -> EventLoopFuture<Channel> {
        return connect0(ipProtocol: ipProtocol) {
            return try SocketAddress.makeAddressResolvingHost(host, port: 0)
        }
    }

    private func connect0(ipProtocol: NIOIPProtocol, _ makeSocketAddress: () throws -> SocketAddress) -> EventLoopFuture<Channel> {
        let address: SocketAddress
        do {
            address = try makeSocketAddress()
        } catch {
            return group.next().makeFailedFuture(error)
        }
        func makeChannel(_ eventLoop: SelectableEventLoop) throws -> DatagramChannel {
            return try DatagramChannel(eventLoop: eventLoop,
                                       protocolFamily: address.protocol,
                                       protocolSubtype: .init(ipProtocol),
                                       socketType: .raw)
        }
        return withNewChannel(makeChannel: makeChannel) { (eventLoop, channel) in
            channel.register().flatMap {
                channel.connect(to: address)
            }
        }
    }

    private func withNewChannel(makeChannel: (_ eventLoop: SelectableEventLoop) throws -> DatagramChannel, _ bringup: @escaping (EventLoop, DatagramChannel) -> EventLoopFuture<Void>) -> EventLoopFuture<Channel> {
        let eventLoop = self.group.next()
        let channelInitializer = self.channelInitializer ?? { _ in eventLoop.makeSucceededFuture(()) }
        let channelOptions = self._channelOptions

        let channel: DatagramChannel
        do {
            channel = try makeChannel(eventLoop as! SelectableEventLoop)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }

        func setupChannel() -> EventLoopFuture<Channel> {
            eventLoop.assertInEventLoop()
            return channelOptions.applyAllChannelOptions(to: channel).flatMap {
                channelInitializer(channel)
            }.flatMap {
                eventLoop.assertInEventLoop()
                return bringup(eventLoop, channel)
            }.map {
                channel
            }.flatMapError { error in
                eventLoop.makeFailedFuture(error)
            }
        }

        if eventLoop.inEventLoop {
            return setupChannel()
        } else {
            return eventLoop.flatSubmit {
                setupChannel()
            }
        }
    }
}

#if swift(>=5.6)
@available(*, unavailable)
extension RawSocketBootstrap: Sendable {}
#endif
