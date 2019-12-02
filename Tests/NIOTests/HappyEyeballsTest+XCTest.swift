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
// HappyEyeballsTest+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension HappyEyeballsTest {

   @available(*, deprecated, message: "not actually deprecated. Just deprecated to allow deprecated tests (which test deprecated functionality) without warnings")
   static var allTests : [(String, (HappyEyeballsTest) -> () throws -> Void)] {
      return [
                ("testIPv4OnlyResolution", testIPv4OnlyResolution),
                ("testIPv6OnlyResolution", testIPv6OnlyResolution),
                ("testTimeOutDuringDNSResolution", testTimeOutDuringDNSResolution),
                ("testAAAAQueryReturningFirst", testAAAAQueryReturningFirst),
                ("testAQueryReturningFirstDelayElapses", testAQueryReturningFirstDelayElapses),
                ("testAQueryReturningFirstThenAAAAReturns", testAQueryReturningFirstThenAAAAReturns),
                ("testAQueryReturningFirstThenAAAAErrors", testAQueryReturningFirstThenAAAAErrors),
                ("testAQueryReturningFirstThenEmptyAAAA", testAQueryReturningFirstThenEmptyAAAA),
                ("testEmptyResultsFail", testEmptyResultsFail),
                ("testAllDNSFail", testAllDNSFail),
                ("testMaximalConnectionDelay", testMaximalConnectionDelay),
                ("testAllConnectionsFail", testAllConnectionsFail),
                ("testDelayedAAAAResult", testDelayedAAAAResult),
                ("testTimeoutWaitingForAAAA", testTimeoutWaitingForAAAA),
                ("testTimeoutAfterAQuery", testTimeoutAfterAQuery),
                ("testAConnectFailsWaitingForAAAA", testAConnectFailsWaitingForAAAA),
                ("testDelayedAResult", testDelayedAResult),
                ("testTimeoutBeforeAResponse", testTimeoutBeforeAResponse),
                ("testAllConnectionsFailImmediately", testAllConnectionsFailImmediately),
                ("testLaterConnections", testLaterConnections),
                ("testDelayedChannelCreation", testDelayedChannelCreation),
                ("testChannelCreationFails", testChannelCreationFails),
                ("testCancellationSyncWithConnectDelay", testCancellationSyncWithConnectDelay),
                ("testCancellationSyncWithResolutionDelay", testCancellationSyncWithResolutionDelay),
           ]
   }
}

