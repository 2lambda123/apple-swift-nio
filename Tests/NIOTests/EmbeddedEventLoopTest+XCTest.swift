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
// EmbeddedEventLoopTest+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension EmbeddedEventLoopTest {
    @available(*, deprecated, message: "not actually deprecated. Just deprecated to allow deprecated tests (which test deprecated functionality) without warnings")
    static var allTests: [(String, (EmbeddedEventLoopTest) -> () throws -> Void)] {
        [
            ("testExecuteDoesNotImmediatelyRunTasks", testExecuteDoesNotImmediatelyRunTasks),
            ("testExecuteWillRunAllTasks", testExecuteWillRunAllTasks),
            ("testExecuteWillRunTasksAddedRecursively", testExecuteWillRunTasksAddedRecursively),
            ("testTasksSubmittedAfterRunDontRun", testTasksSubmittedAfterRunDontRun),
            ("testShutdownGracefullyRunsTasks", testShutdownGracefullyRunsTasks),
            ("testCanControlTime", testCanControlTime),
            ("testCanScheduleMultipleTasks", testCanScheduleMultipleTasks),
            ("testExecutedTasksFromScheduledOnesAreRun", testExecutedTasksFromScheduledOnesAreRun),
            ("testScheduledTasksFromScheduledTasksProperlySchedule", testScheduledTasksFromScheduledTasksProperlySchedule),
            ("testScheduledTasksFromExecutedTasks", testScheduledTasksFromExecutedTasks),
            ("testCancellingScheduledTasks", testCancellingScheduledTasks),
            ("testScheduledTasksFuturesFire", testScheduledTasksFuturesFire),
            ("testScheduledTasksFuturesError", testScheduledTasksFuturesError),
            ("testTaskOrdering", testTaskOrdering),
            ("testCancelledScheduledTasksDoNotHoldOnToRunClosure", testCancelledScheduledTasksDoNotHoldOnToRunClosure),
            ("testDrainScheduledTasks", testDrainScheduledTasks),
            ("testDrainScheduledTasksDoesNotRunNewlyScheduledTasks", testDrainScheduledTasksDoesNotRunNewlyScheduledTasks),
            ("testAdvanceTimeToDeadline", testAdvanceTimeToDeadline),
            ("testWeCantTimeTravelByAdvancingTimeToThePast", testWeCantTimeTravelByAdvancingTimeToThePast),
            ("testExecuteInOrder", testExecuteInOrder),
            ("testScheduledTasksInOrder", testScheduledTasksInOrder),
        ]
    }
}
