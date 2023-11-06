//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Wraps a NIO ``Channel`` object into a form suitable for use in Swift Concurrency.
///
/// ``NIOAsyncChannel`` abstracts the notion of a NIO ``Channel`` into something that
/// can safely be used in a structured concurrency context. In particular, this exposes
/// the following functionality:
///
/// - reads are presented as an `AsyncSequence`
/// - writes can be written to with async functions on a writer, providing back pressure
/// - channels can be closed seamlessly
///
/// This type does not replace the full complexity of NIO's ``Channel``. In particular, it
/// does not expose the following functionality:
///
/// - user events
/// - traditional NIO back pressure such as writability signals and the ``Channel/read()`` call
///
/// Users are encouraged to separate their ``ChannelHandler``s into those that implement
/// protocol-specific logic (such as parsers and encoders) and those that implement business
/// logic. Protocol-specific logic should be implemented as a ``ChannelHandler``, while business
/// logic should use ``NIOAsyncChannel`` to consume and produce data to the network.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct NIOAsyncChannel<Inbound: Sendable, Outbound: Sendable>: Sendable {
    public struct Configuration: Sendable {
        /// The back pressure strategy of the ``NIOAsyncChannel/inbound``.
        public var backPressureStrategy: NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark

        /// If outbound half closure should be enabled. Outbound half closure is triggered once
        /// the ``NIOAsyncChannelOutboundWriter`` is either finished or deinitialized.
        public var isOutboundHalfClosureEnabled: Bool

        /// The ``NIOAsyncChannel/inbound`` message's type.
        public var inboundType: Inbound.Type

        /// The ``NIOAsyncChannel/outbound`` message's type.
        public var outboundType: Outbound.Type

        /// Initializes a new ``NIOAsyncChannel/Configuration``.
        ///
        /// - Parameters:
        ///   - backPressureStrategy: The back pressure strategy of the ``NIOAsyncChannel/inbound``. Defaults
        ///     to a watermarked strategy (lowWatermark: 2, highWatermark: 10).
        ///   - isOutboundHalfClosureEnabled: If outbound half closure should be enabled. Outbound half closure is triggered once
        ///     the ``NIOAsyncChannelOutboundWriter`` is either finished or deinitialized. Defaults to `false`.
        ///   - inboundType: The ``NIOAsyncChannel/inbound`` message's type.
        ///   - outboundType: The ``NIOAsyncChannel/outbound`` message's type.
        public init(
            backPressureStrategy: NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark = .init(lowWatermark: 2, highWatermark: 10),
            isOutboundHalfClosureEnabled: Bool = false,
            inboundType: Inbound.Type = Inbound.self,
            outboundType: Outbound.Type = Outbound.self
        ) {
            self.backPressureStrategy = backPressureStrategy
            self.isOutboundHalfClosureEnabled = isOutboundHalfClosureEnabled
            self.inboundType = inboundType
            self.outboundType = outboundType
        }
    }

    /// The underlying channel being wrapped by this ``NIOAsyncChannel``.
    public let channel: Channel

    /// The stream of inbound messages.
    ///
    /// - Important: The `inbound` stream is a unicast `AsyncSequence` and only one iterator can be created.
    @available(*, deprecated, message: "Use the withInboundOutbound scoped method instead.")
    public var inbound: NIOAsyncChannelInboundStream<Inbound> {
        self._inbound
    }
    /// The writer for writing outbound messages.
    @available(*, deprecated, message: "Use the withInboundOutbound scoped method instead.")
    public var outbound: NIOAsyncChannelOutboundWriter<Outbound> {
        self._outbound
    }

    @usableFromInline
    let _inbound: NIOAsyncChannelInboundStream<Inbound>
    @usableFromInline
    let _outbound: NIOAsyncChannelOutboundWriter<Outbound>

    /// Initializes a new ``NIOAsyncChannel`` wrapping a ``Channel``.
    ///
    /// - Important: This **must** be called on the channel's event loop otherwise this init will crash. This is necessary because
    /// we must install the handlers before any other event in the pipeline happens otherwise we might drop reads.
    ///
    /// - Parameters:
    ///   - channel: The ``Channel`` to wrap.
    ///   - configuration: The ``NIOAsyncChannel``s configuration.
    @inlinable
    public init(
        synchronouslyWrapping channel: Channel,
        configuration: Configuration = .init()
    ) throws {
        channel.eventLoop.preconditionInEventLoop()
        self.channel = channel
        (self._inbound, self._outbound) = try channel._syncAddAsyncHandlers(
            backPressureStrategy: configuration.backPressureStrategy,
            isOutboundHalfClosureEnabled: configuration.isOutboundHalfClosureEnabled
        )
    }

    /// Initializes a new ``NIOAsyncChannel`` wrapping a ``Channel`` where the outbound type is `Never`.
    ///
    /// This initializer will finish the ``NIOAsyncChannel/outbound`` immediately.
    ///
    /// - Important: This **must** be called on the channel's event loop otherwise this init will crash. This is necessary because
    /// we must install the handlers before any other event in the pipeline happens otherwise we might drop reads.
    ///
    /// - Parameters:
    ///   - channel: The ``Channel`` to wrap.
    ///   - configuration: The ``NIOAsyncChannel``s configuration.
    @inlinable
    public init(
        synchronouslyWrapping channel: Channel,
        configuration: Configuration = .init()
    ) throws where Outbound == Never {
        channel.eventLoop.preconditionInEventLoop()
        self.channel = channel
        (self._inbound, self._outbound) = try channel._syncAddAsyncHandlers(
            backPressureStrategy: configuration.backPressureStrategy,
            isOutboundHalfClosureEnabled: configuration.isOutboundHalfClosureEnabled
        )

        self._outbound.finish()
    }

    @inlinable
    internal init(
        channel: Channel,
        inboundStream: NIOAsyncChannelInboundStream<Inbound>,
        outboundWriter: NIOAsyncChannelOutboundWriter<Outbound>
    ) {
        channel.eventLoop.preconditionInEventLoop()
        self.channel = channel
        self._inbound = inboundStream
        self._outbound = outboundWriter
    }


    /// This method is only used from our server bootstrap to allow us to run the child channel initializer
    /// at the right moment.
    ///
    /// - Important: This is not considered stable API and should not be used.
    @inlinable
    public static func _wrapAsyncChannelWithTransformations(
        synchronouslyWrapping channel: Channel,
        backPressureStrategy: NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark? = nil,
        isOutboundHalfClosureEnabled: Bool = false,
        channelReadTransformation: @Sendable @escaping (Channel) -> EventLoopFuture<Inbound>
    ) throws -> NIOAsyncChannel<Inbound, Outbound> where Outbound == Never {
        channel.eventLoop.preconditionInEventLoop()
        let (inboundStream, outboundWriter): (NIOAsyncChannelInboundStream<Inbound>, NIOAsyncChannelOutboundWriter<Outbound>) = try channel._syncAddAsyncHandlersWithTransformations(
            backPressureStrategy: backPressureStrategy,
            isOutboundHalfClosureEnabled: isOutboundHalfClosureEnabled,
            channelReadTransformation: channelReadTransformation
        )

        outboundWriter.finish()

        return .init(
            channel: channel,
            inboundStream: inboundStream,
            outboundWriter: outboundWriter
        )
    }

    /// Provides scoped access to the inbound and outbound side of the underlying ``Channel``.
    ///
    /// - Important: After this method returned the underlying ``Channel`` will be closed.
    ///
    /// - Parameter body: A closure that gets scoped access to the inbound and outbound.
    public func withInboundOutbound<Result>(
        _ body: (NIOAsyncChannelInboundStream<Inbound>, NIOAsyncChannelOutboundWriter<Outbound>) async throws -> Result
    ) async throws -> Result {
        let result: Result
        do {
            result = try await body(self._inbound, self._outbound)
        } catch let bodyError {
            do {
                self._outbound.finish()
                try await self.channel.close().get()
                throw bodyError
            } catch {
                throw bodyError
            }
        }

        do {
            self._outbound.finish()
            try await self.channel.close().get()
        } catch {
            if let error = error as? ChannelError, error == .alreadyClosed {
                return result
            }
            throw error
        }
        return result
    }

    /// Provides scoped access to the inbound side of the underlying ``Channel``.
    ///
    /// - Important: After this method returned the underlying ``Channel`` will be closed.
    ///
    /// - Parameter body: A closure that gets scoped access to the inbound.
    public func withInbound<Result>(
        _ body: (NIOAsyncChannelInboundStream<Inbound>) async throws -> Result
    ) async throws -> Result where Outbound == Never{
        try await self.withInboundOutbound { inbound, _ in
            try await body(inbound)
        }
    }
}

extension Channel {
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @inlinable
    func _syncAddAsyncHandlers<Inbound: Sendable, Outbound: Sendable>(
        backPressureStrategy: NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark?,
        isOutboundHalfClosureEnabled: Bool
    ) throws -> (NIOAsyncChannelInboundStream<Inbound>, NIOAsyncChannelOutboundWriter<Outbound>) {
        self.eventLoop.assertInEventLoop()

        let inboundStream = try NIOAsyncChannelInboundStream<Inbound>.makeWrappingHandler(
            channel: self,
            backPressureStrategy: backPressureStrategy
        )
        let writer = try NIOAsyncChannelOutboundWriter<Outbound>(
            channel: self,
            isOutboundHalfClosureEnabled: isOutboundHalfClosureEnabled
        )
        return (inboundStream, writer)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @inlinable
    func _syncAddAsyncHandlersWithTransformations<ChannelReadResult>(
        backPressureStrategy: NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark?,
        isOutboundHalfClosureEnabled: Bool,
        channelReadTransformation: @Sendable @escaping (Channel) -> EventLoopFuture<ChannelReadResult>
    ) throws -> (NIOAsyncChannelInboundStream<ChannelReadResult>, NIOAsyncChannelOutboundWriter<Never>) {
        self.eventLoop.assertInEventLoop()

        let inboundStream = try NIOAsyncChannelInboundStream<ChannelReadResult>.makeTransformationHandler(
            channel: self,
            backPressureStrategy: backPressureStrategy,
            channelReadTransformation: channelReadTransformation
        )
        let writer = try NIOAsyncChannelOutboundWriter<Never>(
            channel: self,
            isOutboundHalfClosureEnabled: isOutboundHalfClosureEnabled
        )
        return (inboundStream, writer)
    }
}
