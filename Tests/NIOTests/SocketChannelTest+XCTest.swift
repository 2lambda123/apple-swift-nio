//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2019 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
//
// SocketChannelTest+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension SocketChannelTest {

   @available(*, deprecated, message: "not actually deprecated. Just deprecated to allow deprecated tests (which test deprecated functionality) without warnings")
   static var allTests : [(String, (SocketChannelTest) -> () throws -> Void)] {
      return [
                ("testAsyncSetOption", testAsyncSetOption),
                ("testDelayedConnectSetsUpRemotePeerAddress", testDelayedConnectSetsUpRemotePeerAddress),
                ("testAcceptFailsWithECONNABORTED", testAcceptFailsWithECONNABORTED),
                ("testAcceptFailsWithEMFILE", testAcceptFailsWithEMFILE),
                ("testAcceptFailsWithENFILE", testAcceptFailsWithENFILE),
                ("testAcceptFailsWithENOBUFS", testAcceptFailsWithENOBUFS),
                ("testAcceptFailsWithENOMEM", testAcceptFailsWithENOMEM),
                ("testAcceptFailsWithEFAULT", testAcceptFailsWithEFAULT),
                ("testSetGetOptionClosedServerSocketChannel", testSetGetOptionClosedServerSocketChannel),
                ("testConnect", testConnect),
                ("testWriteServerSocketChannel", testWriteServerSocketChannel),
                ("testWriteAndFlushServerSocketChannel", testWriteAndFlushServerSocketChannel),
                ("testConnectServerSocketChannel", testConnectServerSocketChannel),
                ("testCloseDuringWriteFailure", testCloseDuringWriteFailure),
                ("testWithConfiguredStreamSocket", testWithConfiguredStreamSocket),
                ("testWithConfiguredDatagramSocket", testWithConfiguredDatagramSocket),
                ("testPendingConnectNotificationOrder", testPendingConnectNotificationOrder),
                ("testLocalAndRemoteAddressNotNilInChannelInactiveAndHandlerRemoved", testLocalAndRemoteAddressNotNilInChannelInactiveAndHandlerRemoved),
                ("testSocketFlagNONBLOCKWorks", testSocketFlagNONBLOCKWorks),
                ("testInstantTCPConnectionResetThrowsError", testInstantTCPConnectionResetThrowsError),
                ("testUnprocessedOutboundUserEventFailsOnServerSocketChannel", testUnprocessedOutboundUserEventFailsOnServerSocketChannel),
                ("testUnprocessedOutboundUserEventFailsOnSocketChannel", testUnprocessedOutboundUserEventFailsOnSocketChannel),
                ("testSetSockOptDoesNotOverrideExistingFlags", testSetSockOptDoesNotOverrideExistingFlags),
                ("testServerChannelDoesNotBreakIfAcceptingFailsWithEINVAL", testServerChannelDoesNotBreakIfAcceptingFailsWithEINVAL),
                ("testWeAreInterestedInReadEOFWhenChannelIsConnectedOnTheServerSide", testWeAreInterestedInReadEOFWhenChannelIsConnectedOnTheServerSide),
                ("testWeAreInterestedInReadEOFWhenChannelIsConnectedOnTheClientSide", testWeAreInterestedInReadEOFWhenChannelIsConnectedOnTheClientSide),
                ("testServerClosesTheConnectionImmediately", testServerClosesTheConnectionImmediately),
           ]
   }
}

