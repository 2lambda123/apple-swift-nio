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
//
// LinuxMain.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

#if os(Linux) || os(FreeBSD)
   @testable import NIOConcurrencyHelpersTests
   @testable import NIOHTTP1Tests
   @testable import NIOTLSTests
   @testable import NIOTests
   @testable import NIOWebSocketTests

   XCTMain([
         testCase(AcceptBackoffHandlerTest.allTests),
         testCase(AdaptiveRecvByteBufferAllocatorTest.allTests),
         testCase(ApplicationProtocolNegotiationHandlerTests.allTests),
         testCase(Base64Test.allTests),
         testCase(BaseObjectTest.allTests),
         testCase(BlockingIOThreadPoolTest.allTests),
         testCase(ByteBufferTest.allTests),
         testCase(ByteToMessageDecoderTest.allTests),
         testCase(ChannelNotificationTest.allTests),
         testCase(ChannelPipelineTest.allTests),
         testCase(ChannelTests.allTests),
         testCase(CircularBufferTests.allTests),
         testCase(CompositeErrorTests.allTests),
         testCase(DatagramChannelTests.allTests),
         testCase(EchoServerClientTest.allTests),
         testCase(EmbeddedChannelTest.allTests),
         testCase(EmbeddedEventLoopTest.allTests),
         testCase(EndToEndTests.allTests),
         testCase(EventLoopFutureTest.allTests),
         testCase(EventLoopTest.allTests),
         testCase(FileRegionTest.allTests),
         testCase(GetaddrinfoResolverTest.allTests),
         testCase(HTTPDecoderTest.allTests),
         testCase(HTTPHeadersTest.allTests),
         testCase(HTTPRequestEncoderTests.allTests),
         testCase(HTTPResponseCompressorTest.allTests),
         testCase(HTTPResponseEncoderTests.allTests),
         testCase(HTTPServerClientTest.allTests),
         testCase(HTTPServerPipelineHandlerTest.allTests),
         testCase(HTTPServerProtocolErrorHandlerTest.allTests),
         testCase(HTTPTest.allTests),
         testCase(HTTPUpgradeTestCase.allTests),
         testCase(HappyEyeballsTest.allTests),
         testCase(HeapTests.allTests),
         testCase(IdleStateHandlerTest.allTests),
         testCase(MarkedCircularBufferTests.allTests),
         testCase(MessageToByteEncoderTest.allTests),
         testCase(NIOConcurrencyHelpersTests.allTests),
         testCase(NonBlockingFileIOTest.allTests),
         testCase(PendingDatagramWritesManagerTests.allTests),
         testCase(PriorityQueueTest.allTests),
         testCase(SelectorTest.allTests),
         testCase(SniHandlerTest.allTests),
         testCase(SocketAddressTest.allTests),
         testCase(SocketChannelTest.allTests),
         testCase(SystemTest.allTests),
         testCase(ThreadTest.allTests),
         testCase(TypeAssistedChannelHandlerTest.allTests),
         testCase(UtilitiesTest.allTests),
         testCase(WebSocketFrameDecoderTest.allTests),
         testCase(WebSocketFrameEncoderTest.allTests),
    ])
#endif
