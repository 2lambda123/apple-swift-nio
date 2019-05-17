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
// EventCounterHandlerTest+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension EventCounterHandlerTest {

   static var allTests : [(String, (EventCounterHandlerTest) -> () throws -> Void)] {
      return [
                ("testNothingButEmbeddedChannelInit", testNothingButEmbeddedChannelInit),
                ("testNothing", testNothing),
                ("testInboundWrite", testInboundWrite),
                ("testOutboundWrite", testOutboundWrite),
                ("testConnectChannel", testConnectChannel),
                ("testBindChannel", testBindChannel),
                ("testConnectAndCloseChannel", testConnectAndCloseChannel),
                ("testError", testError),
                ("testEventsWithoutArguments", testEventsWithoutArguments),
                ("testInboundUserEvent", testInboundUserEvent),
                ("testOutboundUserEvent", testOutboundUserEvent),
           ]
   }
}

