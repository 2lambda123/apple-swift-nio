//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2019 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import NIO
import NIOTestUtils
import XCTest

typealias VerificationError = ByteToMessageDecoderVerifier.VerificationError<String>

class ByteToMessageDecoderVerifierTest: XCTestCase {
    func testWrongResults() {
        struct AlwaysProduceY: ByteToMessageDecoder {
            typealias InboundOut = String

            func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
                buffer.moveReaderIndex(to: buffer.writerIndex)
                context.fireChannelRead(wrapInboundOut("Y"))
                return .needMoreData
            }

            func decodeLast(context: ChannelHandlerContext,
                            buffer: inout ByteBuffer,
                            seenEOF _: Bool) throws -> DecodingState
            {
                while try decode(context: context, buffer: &buffer) == .continue {}
                return .needMoreData
            }
        }

        XCTAssertThrowsError(try ByteToMessageDecoderVerifier.verifyDecoder(stringInputOutputPairs: [("x", ["x"])],
                                                                            decoderFactory: AlwaysProduceY.init)) {
            error in
            switch error {
            case let error as VerificationError:
                XCTAssertEqual(1, error.inputs.count)
                switch error.errorCode {
                case let .wrongProduction(actual: actual, expected: expected):
                    XCTAssertEqual("Y", actual)
                    XCTAssertEqual("x", expected)
                default:
                    XCTFail("unexpected error: \(error)")
                }
            default:
                XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testNoOutputWhenWeShouldHaveOutput() {
        struct NeverProduce: ByteToMessageDecoder {
            typealias InboundOut = String

            func decode(context _: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
                buffer.moveReaderIndex(to: buffer.writerIndex)
                return .needMoreData
            }

            func decodeLast(context: ChannelHandlerContext,
                            buffer: inout ByteBuffer,
                            seenEOF _: Bool) throws -> DecodingState
            {
                while try decode(context: context, buffer: &buffer) == .continue {}
                return .needMoreData
            }
        }

        XCTAssertThrowsError(try ByteToMessageDecoderVerifier.verifyDecoder(stringInputOutputPairs: [("x", ["x"])],
                                                                            decoderFactory: NeverProduce.init)) {
            error in
            switch error {
            case let error as VerificationError:
                XCTAssertEqual(1, error.inputs.count)
                switch error.errorCode {
                case let .underProduction(expected):
                    XCTAssertEqual("x", expected)
                default:
                    XCTFail("unexpected error: \(error)")
                }
            default:
                XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testOutputWhenWeShouldNotProduceOutput() {
        struct ProduceTooEarly: ByteToMessageDecoder {
            typealias InboundOut = String

            func decode(context: ChannelHandlerContext, buffer _: inout ByteBuffer) throws -> DecodingState {
                context.fireChannelRead(wrapInboundOut("Y"))
                return .needMoreData
            }

            func decodeLast(context: ChannelHandlerContext,
                            buffer: inout ByteBuffer,
                            seenEOF _: Bool) throws -> DecodingState
            {
                while try decode(context: context, buffer: &buffer) == .continue {}
                return .needMoreData
            }
        }

        XCTAssertThrowsError(try ByteToMessageDecoderVerifier.verifyDecoder(stringInputOutputPairs: [("xxxxxx", ["Y"])],
                                                                            decoderFactory: ProduceTooEarly.init)) {
            error in
            switch error {
            case let error as VerificationError:
                switch error.errorCode {
                case let .overProduction(actual):
                    XCTAssertEqual("Y", actual)
                default:
                    XCTFail("unexpected error: \(error)")
                }
            default:
                XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testLeftovers() {
        struct NeverDoAnything: ByteToMessageDecoder {
            typealias InboundOut = String

            func decode(context _: ChannelHandlerContext, buffer _: inout ByteBuffer) throws -> DecodingState {
                .needMoreData
            }

            func decodeLast(context: ChannelHandlerContext,
                            buffer: inout ByteBuffer,
                            seenEOF _: Bool) throws -> DecodingState
            {
                while try decode(context: context, buffer: &buffer) == .continue {}
                if buffer.readableBytes > 0 {
                    context.fireChannelRead(wrapInboundOut("leftover"))
                }
                return .needMoreData
            }
        }

        XCTAssertThrowsError(try ByteToMessageDecoderVerifier.verifyDecoder(stringInputOutputPairs: [("xxxxxx", [])],
                                                                            decoderFactory: NeverDoAnything.init)) {
            error in
            switch error {
            case let error as VerificationError:
                switch error.errorCode {
                case let .leftOversOnDeconstructingChannel(inbound: inbound,
                                                           outbound: outbound,
                                                           pendingOutbound: pending):
                    XCTAssertEqual(0, outbound.count)
                    XCTAssertEqual(["leftover"], inbound.map { $0.tryAs(type: String.self) })
                    XCTAssertEqual(0, pending.count)
                default:
                    XCTFail("unexpected error: \(error)")
                }
            default:
                XCTFail("unexpected error: \(error)")
            }
        }
    }
}
