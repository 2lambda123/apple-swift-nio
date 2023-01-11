//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2023 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
//
// EmbeddedChannelTest+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension EmbeddedChannelTest {

   @available(*, deprecated, message: "not actually deprecated. Just deprecated to allow deprecated tests (which test deprecated functionality) without warnings")
   static var allTests : [(String, (EmbeddedChannelTest) -> () throws -> Void)] {
      return [
                ("testSingleHandlerInit", testSingleHandlerInit),
                ("testSingleHandlerInitNil", testSingleHandlerInitNil),
                ("testMultipleHandlerInit", testMultipleHandlerInit),
                ("testWriteOutboundByteBuffer", testWriteOutboundByteBuffer),
                ("testWriteOutboundByteBufferMultipleTimes", testWriteOutboundByteBufferMultipleTimes),
                ("testWriteInboundByteBuffer", testWriteInboundByteBuffer),
                ("testWriteInboundByteBufferMultipleTimes", testWriteInboundByteBufferMultipleTimes),
                ("testWriteInboundByteBufferReThrow", testWriteInboundByteBufferReThrow),
                ("testWriteOutboundByteBufferReThrow", testWriteOutboundByteBufferReThrow),
                ("testReadOutboundWrongTypeThrows", testReadOutboundWrongTypeThrows),
                ("testReadInboundWrongTypeThrows", testReadInboundWrongTypeThrows),
                ("testWrongTypesWithFastpathTypes", testWrongTypesWithFastpathTypes),
                ("testCloseMultipleTimesThrows", testCloseMultipleTimesThrows),
                ("testCloseOnInactiveIsOk", testCloseOnInactiveIsOk),
                ("testEmbeddedLifecycle", testEmbeddedLifecycle),
                ("testEmbeddedChannelAndPipelineAndChannelCoreShareTheEventLoop", testEmbeddedChannelAndPipelineAndChannelCoreShareTheEventLoop),
                ("testSendingAnythingOnEmbeddedChannel", testSendingAnythingOnEmbeddedChannel),
                ("testActiveWhenConnectPromiseFiresAndInactiveWhenClosePromiseFires", testActiveWhenConnectPromiseFiresAndInactiveWhenClosePromiseFires),
                ("testWriteWithoutFlushDoesNotWrite", testWriteWithoutFlushDoesNotWrite),
                ("testSetLocalAddressAfterSuccessfulBind", testSetLocalAddressAfterSuccessfulBind),
                ("testSetRemoteAddressAfterSuccessfulConnect", testSetRemoteAddressAfterSuccessfulConnect),
                ("testUnprocessedOutboundUserEventFailsOnEmbeddedChannel", testUnprocessedOutboundUserEventFailsOnEmbeddedChannel),
                ("testEmbeddedChannelWritabilityIsWritable", testEmbeddedChannelWritabilityIsWritable),
                ("testFinishWithRecursivelyScheduledTasks", testFinishWithRecursivelyScheduledTasks),
                ("testSyncOptionsAreSupported", testSyncOptionsAreSupported),
                ("testLocalAddress0", testLocalAddress0),
                ("testRemoteAddress0", testRemoteAddress0),
           ]
   }
}

