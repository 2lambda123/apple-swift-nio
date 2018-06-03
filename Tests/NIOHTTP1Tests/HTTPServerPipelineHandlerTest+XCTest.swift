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
// HTTPServerPipelineHandlerTest+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension HTTPServerPipelineHandlerTest {

   static var allTests : [(String, (HTTPServerPipelineHandlerTest) -> () throws -> Void)] {
      return [
                ("testBasicBufferingBehaviour", testBasicBufferingBehaviour),
                ("testReadCallsAreSuppressedWhenPipelining", testReadCallsAreSuppressedWhenPipelining),
                ("testReadCallsAreSuppressedWhenUnbufferingIfThereIsStillBufferedData", testReadCallsAreSuppressedWhenUnbufferingIfThereIsStillBufferedData),
                ("testServerCanRespondEarly", testServerCanRespondEarly),
                ("testPipelineHandlerWillBufferHalfClose", testPipelineHandlerWillBufferHalfClose),
                ("testPipelineHandlerWillDeliverHalfCloseEarly", testPipelineHandlerWillDeliverHalfCloseEarly),
                ("testAReadIsNotIssuedWhenUnbufferingAHalfCloseAfterRequestComplete", testAReadIsNotIssuedWhenUnbufferingAHalfCloseAfterRequestComplete),
                ("testHalfCloseWhileWaitingForResponseIsPassedAlongIfNothingElseBuffered", testHalfCloseWhileWaitingForResponseIsPassedAlongIfNothingElseBuffered),
                ("testRecursiveChannelReadInvocationsDoNotCauseIssues", testRecursiveChannelReadInvocationsDoNotCauseIssues),
                ("testQuiescingEventWhenInitiallyIdle", testQuiescingEventWhenInitiallyIdle),
                ("testQuiescingEventWhenIdleAfterARequest", testQuiescingEventWhenIdleAfterARequest),
                ("testQuiescingInTheMiddleOfARequestNoResponseBitsYet", testQuiescingInTheMiddleOfARequestNoResponseBitsYet),
                ("testQuiescingAfterHavingReceivedRequestButBeforeResponseWasSent", testQuiescingAfterHavingReceivedRequestButBeforeResponseWasSent),
                ("testQuiescingAfterHavingReceivedRequestAndResponseHeadButNoResponseEndYet", testQuiescingAfterHavingReceivedRequestAndResponseHeadButNoResponseEndYet),
                ("testQuiescingAfterRequestAndResponseHeadsButBeforeAnyEndsThenRequestEndBeforeResponseEnd", testQuiescingAfterRequestAndResponseHeadsButBeforeAnyEndsThenRequestEndBeforeResponseEnd),
                ("testQuiescingAfterRequestAndResponseHeadsButBeforeAnyEndsThenRequestEndAfterResponseEnd", testQuiescingAfterRequestAndResponseHeadsButBeforeAnyEndsThenRequestEndAfterResponseEnd),
                ("testQuiescingAfterHavingReceivedOneRequestButBeforeResponseWasSentWithMoreRequestsInTheBuffer", testQuiescingAfterHavingReceivedOneRequestButBeforeResponseWasSentWithMoreRequestsInTheBuffer),
           ]
   }
}

