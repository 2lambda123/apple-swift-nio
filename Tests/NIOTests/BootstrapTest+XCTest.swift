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
// BootstrapTest+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension BootstrapTest {

   @available(*, deprecated, message: "not actually deprecated. Just deprecated to allow deprecated tests (which test deprecated functionality) without warnings")
   static var allTests : [(String, (BootstrapTest) -> () throws -> Void)] {
      return [
                ("testBootstrapsCallInitializersOnCorrectEventLoop", testBootstrapsCallInitializersOnCorrectEventLoop),
                ("testTCPBootstrapsTolerateFuturesFromDifferentEventLoopsReturnedInInitializers", testTCPBootstrapsTolerateFuturesFromDifferentEventLoopsReturnedInInitializers),
                ("testUDPBootstrapToleratesFuturesFromDifferentEventLoopsReturnedInInitializers", testUDPBootstrapToleratesFuturesFromDifferentEventLoopsReturnedInInitializers),
                ("testPreConnectedClientSocketToleratesFuturesFromDifferentEventLoopsReturnedInInitializers", testPreConnectedClientSocketToleratesFuturesFromDifferentEventLoopsReturnedInInitializers),
                ("testPreConnectedServerSocketToleratesFuturesFromDifferentEventLoopsReturnedInInitializers", testPreConnectedServerSocketToleratesFuturesFromDifferentEventLoopsReturnedInInitializers),
                ("testTCPClientBootstrapAllowsConformanceCorrectly", testTCPClientBootstrapAllowsConformanceCorrectly),
                ("testServerBootstrapBindTimeout", testServerBootstrapBindTimeout),
                ("testServerBootstrapSetsChannelOptionsBeforeChannelInitializer", testServerBootstrapSetsChannelOptionsBeforeChannelInitializer),
                ("testClientBootstrapSetsChannelOptionsBeforeChannelInitializer", testClientBootstrapSetsChannelOptionsBeforeChannelInitializer),
                ("testPreConnectedSocketSetsChannelOptionsBeforeChannelInitializer", testPreConnectedSocketSetsChannelOptionsBeforeChannelInitializer),
                ("testDatagramBootstrapSetsChannelOptionsBeforeChannelInitializer", testDatagramBootstrapSetsChannelOptionsBeforeChannelInitializer),
                ("testPipeBootstrapSetsChannelOptionsBeforeChannelInitializer", testPipeBootstrapSetsChannelOptionsBeforeChannelInitializer),
                ("testServerBootstrapAddsAcceptHandlerAfterServerChannelInitialiser", testServerBootstrapAddsAcceptHandlerAfterServerChannelInitialiser),
                ("testClientBootstrapValidatesWorkingELGsCorrectly", testClientBootstrapValidatesWorkingELGsCorrectly),
                ("testClientBootstrapRejectsNotWorkingELGsCorrectly", testClientBootstrapRejectsNotWorkingELGsCorrectly),
                ("testServerBootstrapValidatesWorkingELGsCorrectly", testServerBootstrapValidatesWorkingELGsCorrectly),
                ("testServerBootstrapRejectsNotWorkingELGsCorrectly", testServerBootstrapRejectsNotWorkingELGsCorrectly),
                ("testDatagramBootstrapValidatesWorkingELGsCorrectly", testDatagramBootstrapValidatesWorkingELGsCorrectly),
                ("testDatagramBootstrapRejectsNotWorkingELGsCorrectly", testDatagramBootstrapRejectsNotWorkingELGsCorrectly),
                ("testNIOPipeBootstrapValidatesWorkingELGsCorrectly", testNIOPipeBootstrapValidatesWorkingELGsCorrectly),
                ("testNIOPipeBootstrapRejectsNotWorkingELGsCorrectly", testNIOPipeBootstrapRejectsNotWorkingELGsCorrectly),
                ("testShorthandServerOptionsAreEquivalent", testShorthandServerOptionsAreEquivalent),
                ("testShorthandOptionsAreEquivalentServerChild", testShorthandOptionsAreEquivalentServerChild),
                ("testShorthandOptionsAreEquivalentClient", testShorthandOptionsAreEquivalentClient),
                ("testShorthandOptionsAreEquivalentUniversalClient", testShorthandOptionsAreEquivalentUniversalClient),
                ("testShorthandOptionsAreEquivalentDatagram", testShorthandOptionsAreEquivalentDatagram),
                ("testShorthandOptionsAreEquivalentPipe", testShorthandOptionsAreEquivalentPipe),
           ]
   }
}

