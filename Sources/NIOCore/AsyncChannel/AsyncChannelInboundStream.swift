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

/// The inbound message asynchronous sequence of a ``NIOAsyncChannel``.
///
/// This is a unicast async sequence that allows a single iterator to be created.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
@_spi(AsyncChannel)
public struct NIOAsyncChannelInboundStream<Inbound: Sendable>: Sendable {
    @usableFromInline
    typealias Producer = NIOThrowingAsyncSequenceProducer<Inbound, Error, NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark, NIOAsyncChannelInboundStreamChannelHandlerProducerDelegate>

    /// The underlying async sequence.
    @usableFromInline let _producer: Producer

    @inlinable
    init(
        channel: Channel,
        backpressureStrategy: NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark?,
        closeRatchet: CloseRatchet
    ) throws {
        let handler = NIOAsyncChannelInboundStreamChannelHandler<Inbound, Inbound>(
            eventLoop: channel.eventLoop,
            closeRatchet: closeRatchet
        )

        try self.init(
            channel: channel,
            backpressureStrategy: backpressureStrategy,
            closeRatchet: closeRatchet,
            handler: handler
        )
    }

    @inlinable
    init<ChannelHandlerInboundIn: Sendable>(
        channel: Channel,
        backpressureStrategy: NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark?,
        closeRatchet: CloseRatchet,
        transformationClosure: @escaping (ChannelHandlerInboundIn) throws -> Inbound
    ) throws {
        let handler = NIOAsyncChannelInboundStreamChannelHandler<ChannelHandlerInboundIn, Inbound>(
            eventLoop: channel.eventLoop,
            closeRatchet: closeRatchet,
            transformationClosure: transformationClosure
        )

        try self.init(
            channel: channel,
            backpressureStrategy: backpressureStrategy,
            closeRatchet: closeRatchet,
            handler: handler
        )
    }

    @inlinable
    init(
        channel: Channel,
        backpressureStrategy: NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark?,
        closeRatchet: CloseRatchet,
        protocolNegotiationClosure: @escaping (Channel) -> EventLoopFuture<Inbound>
    ) throws {
        let handler = NIOAsyncChannelInboundStreamChannelHandler<Channel, Inbound>(
            eventLoop: channel.eventLoop,
            closeRatchet: closeRatchet,
            protocolNegotiationClosure: protocolNegotiationClosure
        )

        try self.init(
            channel: channel,
            backpressureStrategy: backpressureStrategy,
            closeRatchet: closeRatchet,
            handler: handler
        )
    }

    @inlinable
    init<HandlerInbound: Sendable>(
        channel: Channel,
        backpressureStrategy: NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark?,
        closeRatchet: CloseRatchet,
        handler: NIOAsyncChannelInboundStreamChannelHandler<HandlerInbound, Inbound>
    ) throws {
        channel.eventLoop.preconditionInEventLoop()
        let strategy: NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark

        if let userProvided = backpressureStrategy {
            strategy = userProvided
        } else {
            // Default strategy. These numbers are fairly arbitrary, but they line up with the default value of
            // maxMessagesPerRead.
            strategy = .init(lowWatermark: 2, highWatermark: 10)
        }

        let sequence = Producer.makeSequence(
            backPressureStrategy: strategy,
            delegate: NIOAsyncChannelInboundStreamChannelHandlerProducerDelegate(handler: handler)
        )
        handler.source = sequence.source
        try channel.pipeline.syncOperations.addHandler(handler)
        self._producer = sequence.sequence
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension NIOAsyncChannelInboundStream: AsyncSequence {
    @_spi(AsyncChannel)
    public typealias Element = Inbound

    @_spi(AsyncChannel)
    public struct AsyncIterator: AsyncIteratorProtocol {
        @usableFromInline var _iterator: Producer.AsyncIterator

        @inlinable
        init(_ iterator: Producer.AsyncIterator) {
            self._iterator = iterator
        }

        @inlinable @_spi(AsyncChannel)
        public mutating func next() async throws -> Element? {
            return try await self._iterator.next()
        }
    }

    @inlinable
    @_spi(AsyncChannel)
    public func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(self._producer.makeAsyncIterator())
    }
}

/// The ``NIOAsyncChannelInboundStream/AsyncIterator`` MUST NOT be shared across `Task`s. With marking this as
/// unavailable we are explicitly declaring this.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
@available(*, unavailable)
extension NIOAsyncChannelInboundStream.AsyncIterator: Sendable {}

