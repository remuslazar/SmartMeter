//
//  SmartMeterTests.swift
//  SmartMeterTests
//
//  Created by Remus Lazar on 02.01.16.
//  Copyright © 2016 Remus Lazar. All rights reserved.
//

import XCTest

class SmartMeterTests: XCTestCase {
    
    var testBundle: NSBundle!
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        testBundle = NSBundle(forClass: self.classForCoder)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testPowerMeterXMLParsing() {
        
        // get the URL of the XML test file
        let url = testBundle.URLForResource("getPowerProfileTest", withExtension: "xml")!
        
        let parsingDone = expectationWithDescription("parsed")
        
        // parse the XML
        PowerProfile.parse(url) {
            if let powerProfile = $0 as? PowerProfile {
                XCTAssertNotNil(powerProfile.v)
                XCTAssertEqual(powerProfile.v.count, 100)
                
                XCTAssertNotNil(powerProfile.startts)
                XCTAssertNotNil(powerProfile.endts)
                
                XCTAssertEqual("\(powerProfile.startts!)", "2016-01-02 16:13:10 +0000")
                XCTAssertEqual("\(powerProfile.endts!)", "2016-01-02 16:14:49 +0000")
                
                XCTAssertEqual(powerProfile.v.first, 550)
                XCTAssertEqual(powerProfile.v.last, 538)
            } else {
                XCTFail()
            }
            
            parsingDone.fulfill()
        }
        
        waitForExpectationsWithTimeout(5) { error in
            XCTAssertNil(error, "parse operation timed out after 5 seconds")
        }
    }
    
    
}
