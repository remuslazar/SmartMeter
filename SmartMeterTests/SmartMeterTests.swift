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
        
        var powerProfile: PowerProfile!
        
        // parse the XML
        PowerProfile.parse(url) {
            powerProfile = $0 as! PowerProfile
            parsingDone.fulfill()
        }
        
        waitForExpectationsWithTimeout(2, handler: nil)

        XCTAssertNotNil(powerProfile.v)
        XCTAssertEqual(powerProfile.v.count, 100)
        
        XCTAssertNotNil(powerProfile.startts)
        XCTAssertNotNil(powerProfile.endts)
        
        XCTAssertEqual("\(powerProfile.startts!)", "2016-01-02 16:13:10 +0000")
        XCTAssertEqual("\(powerProfile.endts!)", "2016-01-02 16:14:49 +0000")
        
        XCTAssertEqual(powerProfile.v.first, 550)
        XCTAssertEqual(powerProfile.v.last, 538)
    }
    
    func testXMLParsingPerformance() {

        // get the URL of the XML test file
        let url = self.testBundle.URLForResource("getPowerProfileTest", withExtension: "xml")!
        var powerProfile: PowerProfile!
        
        self.measureBlock {
            let parsingDone = self.expectationWithDescription("parsed")
            // parse the XML
            PowerProfile.parse(url) {
                powerProfile = $0 as! PowerProfile
                parsingDone.fulfill()
            }
            
            self.waitForExpectationsWithTimeout(2, handler: nil)
            XCTAssertEqual(powerProfile.v.count, 100)
        }
    }
    
    class MockPowerProfile : PowerProfile {
        init(startts: NSDate, data: [Int]) {
            super.init(url: NSURL()) { (dummy) -> Void in
                
            }
            self.endts = startts.dateByAddingTimeInterval(NSTimeInterval(data.count-1))
            self.v = data
        }
    }
    
    func testHistoryModule() {
        
        let history = PowerMeter.History(size: 10)
        let powerProfile = MockPowerProfile(startts: NSDate(timeIntervalSince1970: 0), data: [100,200])
        
        // test PowerProfile startts calculation
        XCTAssertEqual(powerProfile.startts, NSDate(timeIntervalSince1970: 0))

        // add data
        history.add(powerProfile)
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history.getSample(0)?.value, 100)
        XCTAssertEqual(history.getSample(1)?.value, 200)

        XCTAssertEqual(history.startts, powerProfile.startts)
        XCTAssertEqual(history.endts, powerProfile.endts)

        // add a new PowerProfile to the history with overlap
        let powerProfile2 = MockPowerProfile(startts: NSDate(timeIntervalSince1970: 1), data: [200,110,210])
        history.add(powerProfile2)
        XCTAssertEqual(history.count, 4)
        XCTAssertEqual(history.getSample(0)?.value, 100)
        XCTAssertEqual(history.getSample(3)?.value, 210)
        
        XCTAssertEqual(history.startts, powerProfile.startts)
        XCTAssertEqual(history.endts, powerProfile2.endts)
        
        // changing size of the history
        history.size = 3
        XCTAssertEqual(history.count, 3)
        XCTAssertEqual(history.getSample(0)?.value, 200)
        
        // test the prepend method (this method inserts new data at the begining)
        history.purge()
        history.size = 100
        history.add(MockPowerProfile(startts: NSDate(timeIntervalSince1970: 10), data: [100,200]))
        XCTAssertEqual(history.count, 2)
        // prepend a new PowerProfile to the history without overlap
        history.prepend(MockPowerProfile(startts: NSDate(timeIntervalSince1970: 8), data: [1,2]))
        XCTAssertEqual(history.count, 4)
        XCTAssertEqual(history.getSample(0)?.value, 1)
        
        // prepend a new PowerProfile to the history with overlap
        history.prepend(MockPowerProfile(startts: NSDate(timeIntervalSince1970: 7), data: [12,0]))
        XCTAssertEqual(history.count, 5)
        XCTAssertEqual(history.getSample(0)?.value, 12)

        // prepend a new PowerProfile to the history with overlap and nil values
        history.prepend(MockPowerProfile(startts: NSDate(timeIntervalSince1970: 0), data: [0,1,2]))
        XCTAssertEqual(history.count, 12)
        XCTAssertEqual(history.getSample(0)?.value, 0)
        XCTAssertEqual(history.getSample(3)?.value, nil)
    }
    
    
}
