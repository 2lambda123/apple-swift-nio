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
// EventLoopFutureTest+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension EventLoopFutureTest {
    @available(*, deprecated, message: "not actually deprecated. Just deprecated to allow deprecated tests (which test deprecated functionality) without warnings")
    static var allTests: [(String, (EventLoopFutureTest) -> () throws -> Void)] {
        [
            ("testFutureFulfilledIfHasResult", testFutureFulfilledIfHasResult),
            ("testFutureFulfilledIfHasError", testFutureFulfilledIfHasError),
            ("testFoldWithMultipleEventLoops", testFoldWithMultipleEventLoops),
            ("testFoldWithSuccessAndAllSuccesses", testFoldWithSuccessAndAllSuccesses),
            ("testFoldWithSuccessAndOneFailure", testFoldWithSuccessAndOneFailure),
            ("testFoldWithSuccessAndEmptyFutureList", testFoldWithSuccessAndEmptyFutureList),
            ("testFoldWithFailureAndEmptyFutureList", testFoldWithFailureAndEmptyFutureList),
            ("testFoldWithFailureAndAllSuccesses", testFoldWithFailureAndAllSuccesses),
            ("testFoldWithFailureAndAllUnfulfilled", testFoldWithFailureAndAllUnfulfilled),
            ("testFoldWithFailureAndAllFailures", testFoldWithFailureAndAllFailures),
            ("testAndAllWithEmptyFutureList", testAndAllWithEmptyFutureList),
            ("testAndAllWithAllSuccesses", testAndAllWithAllSuccesses),
            ("testAndAllWithAllFailures", testAndAllWithAllFailures),
            ("testAndAllWithOneFailure", testAndAllWithOneFailure),
            ("testReduceWithAllSuccesses", testReduceWithAllSuccesses),
            ("testReduceWithOnlyInitialValue", testReduceWithOnlyInitialValue),
            ("testReduceWithAllFailures", testReduceWithAllFailures),
            ("testReduceWithOneFailure", testReduceWithOneFailure),
            ("testReduceWhichDoesFailFast", testReduceWhichDoesFailFast),
            ("testReduceIntoWithAllSuccesses", testReduceIntoWithAllSuccesses),
            ("testReduceIntoWithEmptyFutureList", testReduceIntoWithEmptyFutureList),
            ("testReduceIntoWithAllFailure", testReduceIntoWithAllFailure),
            ("testReduceIntoWithMultipleEventLoops", testReduceIntoWithMultipleEventLoops),
            ("testThenThrowingWhichDoesNotThrow", testThenThrowingWhichDoesNotThrow),
            ("testThenThrowingWhichDoesThrow", testThenThrowingWhichDoesThrow),
            ("testflatMapErrorThrowingWhichDoesNotThrow", testflatMapErrorThrowingWhichDoesNotThrow),
            ("testflatMapErrorThrowingWhichDoesThrow", testflatMapErrorThrowingWhichDoesThrow),
            ("testOrderOfFutureCompletion", testOrderOfFutureCompletion),
            ("testEventLoopHoppingInThen", testEventLoopHoppingInThen),
            ("testEventLoopHoppingInThenWithFailures", testEventLoopHoppingInThenWithFailures),
            ("testEventLoopHoppingAndAll", testEventLoopHoppingAndAll),
            ("testEventLoopHoppingAndAllWithFailures", testEventLoopHoppingAndAllWithFailures),
            ("testFutureInVariousScenarios", testFutureInVariousScenarios),
            ("testLoopHoppingHelperSuccess", testLoopHoppingHelperSuccess),
            ("testLoopHoppingHelperFailure", testLoopHoppingHelperFailure),
            ("testLoopHoppingHelperNoHopping", testLoopHoppingHelperNoHopping),
            ("testFlatMapResultHappyPath", testFlatMapResultHappyPath),
            ("testFlatMapResultFailurePath", testFlatMapResultFailurePath),
            ("testWhenAllSucceedFailsImmediately", testWhenAllSucceedFailsImmediately),
            ("testWhenAllSucceedResolvesAfterFutures", testWhenAllSucceedResolvesAfterFutures),
            ("testWhenAllSucceedIsIndependentOfFulfillmentOrder", testWhenAllSucceedIsIndependentOfFulfillmentOrder),
            ("testWhenAllCompleteResultsWithFailuresStillSucceed", testWhenAllCompleteResultsWithFailuresStillSucceed),
            ("testWhenAllCompleteResults", testWhenAllCompleteResults),
            ("testWhenAllCompleteResolvesAfterFutures", testWhenAllCompleteResolvesAfterFutures),
            ("testAlways", testAlways),
            ("testAlwaysWithFailingPromise", testAlwaysWithFailingPromise),
            ("testPromiseCompletedWithSuccessfulFuture", testPromiseCompletedWithSuccessfulFuture),
            ("testPromiseCompletedWithFailedFuture", testPromiseCompletedWithFailedFuture),
            ("testPromiseCompletedWithSuccessfulResult", testPromiseCompletedWithSuccessfulResult),
            ("testPromiseCompletedWithFailedResult", testPromiseCompletedWithFailedResult),
            ("testAndAllCompleteWithZeroFutures", testAndAllCompleteWithZeroFutures),
            ("testAndAllSucceedWithZeroFutures", testAndAllSucceedWithZeroFutures),
            ("testAndAllCompleteWithPreSucceededFutures", testAndAllCompleteWithPreSucceededFutures),
            ("testAndAllCompleteWithPreFailedFutures", testAndAllCompleteWithPreFailedFutures),
            ("testAndAllCompleteWithMixOfPreSuccededAndNotYetCompletedFutures", testAndAllCompleteWithMixOfPreSuccededAndNotYetCompletedFutures),
            ("testWhenAllCompleteWithMixOfPreSuccededAndNotYetCompletedFutures", testWhenAllCompleteWithMixOfPreSuccededAndNotYetCompletedFutures),
            ("testRepeatedTaskOffEventLoopGroupFuture", testRepeatedTaskOffEventLoopGroupFuture),
            ("testEventLoopFutureOrErrorNoThrow", testEventLoopFutureOrErrorNoThrow),
            ("testEventLoopFutureOrThrows", testEventLoopFutureOrThrows),
            ("testEventLoopFutureOrNoReplacement", testEventLoopFutureOrNoReplacement),
            ("testEventLoopFutureOrReplacement", testEventLoopFutureOrReplacement),
            ("testEventLoopFutureOrNoElse", testEventLoopFutureOrNoElse),
            ("testEventLoopFutureOrElse", testEventLoopFutureOrElse),
            ("testFlatBlockingMapOnto", testFlatBlockingMapOnto),
            ("testWhenSuccessBlocking", testWhenSuccessBlocking),
            ("testWhenFailureBlocking", testWhenFailureBlocking),
            ("testWhenCompleteBlockingSuccess", testWhenCompleteBlockingSuccess),
            ("testWhenCompleteBlockingFailure", testWhenCompleteBlockingFailure),
        ]
    }
}
