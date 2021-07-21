//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import XCTest
import NIO
import NIOFoundationCompat

class JSONSerializationByteBufferTest: XCTestCase {
    
    func testSerializationRoundTrip() {
        
        let array = ["String1", "String2", "String3"]
        let dictionary = ["key1": "val1", "key2": "val2", "key3": "val3"]
        
        var dataArray = Data()
        var dataDictionary = Data()
        
        XCTAssertTrue(JSONSerialization.isValidJSONObject(array), "Array object cannot be converted to JSON")
        XCTAssertTrue(JSONSerialization.isValidJSONObject(dictionary), "Dictionary object cannot be converted to JSON")
        
        XCTAssertNoThrow(dataArray = try JSONSerialization.data(withJSONObject: array, options: .prettyPrinted))
        XCTAssertNoThrow(dataDictionary = try JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted))
        
        let arrayByteBuffer = ByteBuffer(data: Data(dataArray))
        let dictByteBuffer = ByteBuffer(data: Data(dataDictionary))
        
        var foundationArray: [String] = []
        var foundationDict: [String: String] = [:]
        
        XCTAssertNoThrow(foundationArray = try JSONSerialization.jsonObject(Array<String>.self, buffer: arrayByteBuffer)!)
        XCTAssertEqual(foundationArray, array)
        
        XCTAssertNoThrow(foundationDict = try JSONSerialization.jsonObject(Dictionary<String, String>.self, buffer: dictByteBuffer)!)
        XCTAssertEqual(foundationDict, dictionary)
    }
}
