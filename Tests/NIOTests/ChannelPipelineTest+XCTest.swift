//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
//
// ChannelPipelineTest+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension ChannelPipelineTest {
    @available(*, deprecated, message: "not actually deprecated. Just deprecated to allow deprecated tests (which test deprecated functionality) without warnings")
    static var allTests: [(String, (ChannelPipelineTest) -> () throws -> Void)] {
        [
            ("testGetHandler", testGetHandler),
            ("testGetFirstHandler", testGetFirstHandler),
            ("testGetNotAddedHandler", testGetNotAddedHandler),
            ("testAddAfterClose", testAddAfterClose),
            ("testOutboundOrdering", testOutboundOrdering),
            ("testConnectingDoesntCallBind", testConnectingDoesntCallBind),
            ("testFiringChannelReadsInHandlerRemovedWorks", testFiringChannelReadsInHandlerRemovedWorks),
            ("testEmptyPipelineWorks", testEmptyPipelineWorks),
            ("testWriteAfterClose", testWriteAfterClose),
            ("testOutboundNextForInboundOnlyIsCorrect", testOutboundNextForInboundOnlyIsCorrect),
            ("testChannelInfrastructureIsNotLeaked", testChannelInfrastructureIsNotLeaked),
            ("testAddingHandlersFirstWorks", testAddingHandlersFirstWorks),
            ("testAddAfter", testAddAfter),
            ("testAddBefore", testAddBefore),
            ("testAddAfterLast", testAddAfterLast),
            ("testAddBeforeFirst", testAddBeforeFirst),
            ("testAddAfterWhileClosed", testAddAfterWhileClosed),
            ("testAddBeforeWhileClosed", testAddBeforeWhileClosed),
            ("testFindHandlerByType", testFindHandlerByType),
            ("testFindHandlerByTypeReturnsTheFirstOfItsType", testFindHandlerByTypeReturnsTheFirstOfItsType),
            ("testContextForHeadOrTail", testContextForHeadOrTail),
            ("testRemoveHeadOrTail", testRemoveHeadOrTail),
            ("testRemovingByContextWithPromiseStillInChannel", testRemovingByContextWithPromiseStillInChannel),
            ("testRemovingByContextWithFutureNotInChannel", testRemovingByContextWithFutureNotInChannel),
            ("testRemovingByNameWithPromiseStillInChannel", testRemovingByNameWithPromiseStillInChannel),
            ("testRemovingByNameWithFutureNotInChannel", testRemovingByNameWithFutureNotInChannel),
            ("testRemovingByReferenceWithPromiseStillInChannel", testRemovingByReferenceWithPromiseStillInChannel),
            ("testRemovingByReferenceWithFutureNotInChannel", testRemovingByReferenceWithFutureNotInChannel),
            ("testFireChannelReadInInactiveChannelDoesNotCrash", testFireChannelReadInInactiveChannelDoesNotCrash),
            ("testTeardownDuringFormalRemovalProcess", testTeardownDuringFormalRemovalProcess),
            ("testVariousChannelRemovalAPIsGoThroughRemovableChannelHandler", testVariousChannelRemovalAPIsGoThroughRemovableChannelHandler),
            ("testNonRemovableChannelHandlerIsNotRemovable", testNonRemovableChannelHandlerIsNotRemovable),
            ("testAddMultipleHandlers", testAddMultipleHandlers),
            ("testPipelineDebugDescription", testPipelineDebugDescription),
            ("testWeDontCallHandlerRemovedTwiceIfAHandlerCompletesRemovalOnlyAfterChannelTeardown", testWeDontCallHandlerRemovedTwiceIfAHandlerCompletesRemovalOnlyAfterChannelTeardown),
            ("testWeFailTheSecondRemoval", testWeFailTheSecondRemoval),
            ("testSynchronousViewAddHandler", testSynchronousViewAddHandler),
            ("testSynchronousViewAddHandlerAfterDestroyed", testSynchronousViewAddHandlerAfterDestroyed),
            ("testSynchronousViewAddHandlers", testSynchronousViewAddHandlers),
            ("testSynchronousViewContext", testSynchronousViewContext),
            ("testSynchronousViewGetTypedHandler", testSynchronousViewGetTypedHandler),
        ]
    }
}
