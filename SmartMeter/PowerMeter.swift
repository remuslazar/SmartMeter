//
//  PowerMeter.swift
//  SmartMeter
//
//  Created by Remus Lazar on 15.06.15.
//  Copyright (c) 2015 Remus Lazar. All rights reserved.
//

import Foundation

protocol PowerMeterDelegate {
    // will be called on the main queue
    func didUpdateWattage(currentWattage: Int)
}

class PowerMeter: NSObject {
    
    // MARK: - public API
    
    var delegate: PowerMeterDelegate?

    let host: String!
    init(host: String) {
        self.host = host
    }
    
    var numberOfSamplesNeeded: Double? {
        if timeSkew != nil {
            if let lastRequestDate = lastTimestamp?.dateByAddingTimeInterval(-timeSkew!) {
                return -lastRequestDate.timeIntervalSinceNow
            }
        }
        return nil
    }
    
    var history = History()
    
    // read the current wattage from the power meter asynchronously
    // will call the callback in the main queue
    func readCurrentWattage(completionHandler: (Int?) -> Void) {
        if let url = NSURL(scheme: "http", host: host, path: "/InstantView/request/getPowerProfile.html"),
            let u = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)
        {
            
            var n = "1" // default
            if let double = numberOfSamplesNeeded {
                let number = NSNumber(double: double+3)
                n = "\(number.integerValue)"
            }
            
            u.queryItems = [
                NSURLQueryItem(name: "ts", value: "0"),
                NSURLQueryItem(name: "n", value: n)
            ]
            let requestBeginTimestamp = NSDate()
            PowerProfile.parse(u.URL!) {
                if let powerProfile = $0 as? PowerProfile{
                    //println("readCurrentWattage: wattage: \(powerProfile.v.last)W, ts: \(powerProfile.startts)")
                    if let ts = powerProfile.endts {
                        self.history.add(powerProfile)
                        self.lastTimestamp = ts
                        self.timeSkew = self.lastTimestamp!.timeIntervalSinceDate(requestBeginTimestamp)
//                        println("lastTS: \(self.lastTimestamp), startts: \(powerProfile.startts), endts: \(powerProfile.endts)")
                    }
                    completionHandler(powerProfile.v.last)
                }
            }
        } else {
            completionHandler(nil)
        }
    }
    
    // read the device info from the power meter asynchronously
    // will call the callback in the main queue
    func readDeviceInfo(completionHandler: ([String: String]?) -> Void) {
        if let url = NSURL(scheme: "http", host: host, path: "/wikidesc.xml") {
            PowerMeterDeviceInfo.parse(url) {
                if let deviceInfo = $0 as? PowerMeterDeviceInfo {
                    //println("readDeviceInfo: \(deviceInfo)")
                    completionHandler(deviceInfo.info)
                }
            }
        } else {
            completionHandler(nil)
        }
    }

    func startUpdatingCurrentWattage() {
        update()
        setupTimer()
    }

    func stopUpdatingCurrentWattage() {
        timer?.invalidate()
        timer = nil
    }
    
    var autoUpdateTimeInterval = NSTimeInterval(3) {
        didSet {
            if timer != nil { // update the current timer
                setupTimer()
            }
        }
    }
    
    // MARK: - Private data
    
    private var timer: NSTimer?
    
    private func setupTimer() {
        timer?.invalidate()
        timer = NSTimer.scheduledTimerWithTimeInterval(autoUpdateTimeInterval, target: self, selector: Selector("update"),
            userInfo: nil, repeats: true)
    }
    
    private var lastRequestStillPending = false
    private var lastTimestamp: NSDate?

    // time skew of the power meter device (negative means that the device RTC is late)
    private var timeSkew: NSTimeInterval?

    func update() {
        if delegate == nil || lastRequestStillPending { return }
        lastRequestStillPending = true
        readCurrentWattage {
            self.lastRequestStillPending = false
            if let value = $0 {
                self.delegate?.didUpdateWattage(value)
            }
        }
    }
    
    
    class History {

        struct PowerSample {
            let timestamp: NSDate
            let value: Int?
        }

        private var data = [Int?]()
        private var startts: NSDate?
        let sampleRate = 1.0 // in seconds
        
        var endts: NSDate? {
            return startts?.dateByAddingTimeInterval(Double(data.count))
        }
        
        var count: Int {
            return data.count
        }
        
        func getSample(index: Int) -> PowerSample? {
            if index < data.count {
                return PowerSample(
                    timestamp: startts!.dateByAddingTimeInterval(Double(index) * sampleRate),
                    value: data[index]
                )
            }
            return nil
        }
        
        func add(powerProfile: PowerProfile) {
            if startts == nil {
                startts = powerProfile.startts
                data = powerProfile.v.map { $0 }
            } else {
                let offset = powerProfile.startts!.timeIntervalSinceDate(endts!) - sampleRate
                if (offset > 0) {
                    // we are missing offset values, fill them with nil values
                    for _ in 1...Int(offset) { data.append(nil) }
                } else {
                    let skip = Int(-offset)
                    if (skip < powerProfile.v.count) {
                        for index in skip..<powerProfile.v.count { data.append(powerProfile.v[index]) }
                    }
                }
            }
            //println("\(data)")
        }
        
    }
    
}

class PowerMeterDeviceInfo : PowerMeterXMLData {

    var info = [String: String]()
    
    class func parse(url: NSURL, completionHandler: PowerMeterXMLDataCompletionHandler) {
        PowerMeterDeviceInfo(url: url, completionHandler: completionHandler).parse()
    }
    
    // to simplify things, just take all xml elements and put them in a flat list
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?,
        attributes attributeDict: [NSObject : AnyObject]) {
            input = ""
    }
    
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        info[elementName] = input
    }
}


class PowerProfile : PowerMeterXMLData {

    var v = [Int]()
    var startts, endts: NSDate?

    class func parse(url: NSURL, completionHandler: PowerMeterXMLDataCompletionHandler) {
        PowerProfile(url: url, completionHandler: completionHandler).parse()
    }
    
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?,
        attributes attributeDict: [NSObject : AnyObject]) {
            switch elementName {
            case "header": inHeader = true
            default: break
            }
            input = ""
    }
    
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "header": inHeader = false
        case "v":
            if !inHeader, let value = NSNumberFormatter().numberFromString(input)?.integerValue {
                v.append(value)
            }
        case "startts": if inHeader { startts = powerMeterDateFormatter.dateFromString(input) }
        case "endts": if inHeader { endts = powerMeterDateFormatter.dateFromString(input) }
        default: break
        }
    }
    
    let powerMeterDateFormatter: NSDateFormatter = {
        var formatter = NSDateFormatter()
        formatter.dateFormat = "yyMMddHHmmss's'"
        return formatter
    }()

}

class PowerMeterXMLData : NSObject, Printable, NSXMLParserDelegate {
    
    typealias PowerMeterXMLDataCompletionHandler = (PowerMeterXMLData?) -> Void
    private let completionHandler: PowerMeterXMLDataCompletionHandler

    init(url: NSURL, completionHandler: PowerMeterXMLDataCompletionHandler) {
        self.url = url
        self.completionHandler = completionHandler
    }
    
    private let url: NSURL
    
    private func parse() {
        let qos = Int(QOS_CLASS_USER_INITIATED.value)
        dispatch_async(dispatch_get_global_queue(qos, 0)) {
            if let data = NSData(contentsOfURL: self.url) {
                let parser = NSXMLParser(data: data)
                parser.delegate = self
                parser.shouldProcessNamespaces = false
                parser.shouldReportNamespacePrefixes = false
                parser.shouldResolveExternalEntities = false
                parser.parse()
            } else {
                self.fail()
            }
        }
        
    }

    // helper vars for XML parsing
    private var input = ""
    private var inHeader = false
    
    private func fail() { complete(success: false) }
    private func succeed() { complete(success: true) }

    private func complete(#success: Bool) {
        dispatch_async(dispatch_get_main_queue()) {
            self.completionHandler(success ? self : nil)
        }
    }
    
    // MARK: - NSXMLParser Delegate

    func parserDidEndDocument(parser: NSXMLParser) { succeed() }
    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) { fail() }
    func parser(parser: NSXMLParser, validationErrorOccurred validationError: NSError) { fail() }
    
    func parser(parser: NSXMLParser, foundCharacters string: String?) {
        input += string!
    }
}
