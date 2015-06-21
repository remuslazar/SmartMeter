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
    
    init(host: String) { self.host = host }

    let host: String!
    var delegate: PowerMeterDelegate?
    var history = History()
    
    // read the current wattage from the power meter asynchronously
    // will call the callback in the main queue
    func readCurrentWattage(completionHandler: (Int?) -> Void) {
        
        var numSamples = 1 // default
        if let offset = lastPowermeterUpdate?.timeIntervalSinceNow {
            numSamples = Int(-offset) + 5
        }
        numSamples = min(numSamples,100)
        let requestBeginTimestamp = NSDate()
        lastPowermeterUpdate = NSDate()

        readPowerProfile(numSamples: numSamples, lastts: nil) {
            if let powerProfile = $0 {
                //println("readCurrentWattage: wattage: \(powerProfile.v.last)W, ts: \(powerProfile.startts)")
                if let ts = powerProfile.endts {
                    self.history.add(powerProfile)
                    self.lastTimestamp = ts
                    if (self.timeSkew == nil) { self.timeSkew = self.lastTimestamp!.timeIntervalSinceDate(requestBeginTimestamp) }
//                    println("lastTS: \(self.lastTimestamp), startts: \(powerProfile.startts), endts: \(powerProfile.endts)")
                }
                completionHandler(powerProfile.v.last)
            }
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
    private var lastPowermeterUpdate: NSDate?

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
    
    // generic function to read a specific power profile from the power meter
    private func readPowerProfile(#numSamples: Int, lastts: NSDate?, completionHandler: (PowerProfile?) -> Void) {
        if let url = NSURL(scheme: "http", host: host, path: "/InstantView/request/getPowerProfile.html"),
            let u = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)
        {
            u.queryItems = [
                NSURLQueryItem(name: "ts", value: PowerProfile.timestampFromDate(lastts)),
                NSURLQueryItem(name: "n", value: "\(numSamples)")
            ]
            PowerProfile.parse(u.URL!) {
                if let powerProfile = $0 as? PowerProfile {
                    completionHandler(powerProfile)
                }
            }
        } else {
            completionHandler(nil)
        }
    }
    
    class History {

        struct PowerSample {
            let timestamp: NSDate
            let value: Int?
        }

        private var data = [Int?]()
        let sampleRate = 1.0 // in seconds
        var startts: NSDate?
        
        var endts: NSDate? {
            return startts?.dateByAddingTimeInterval(Double(data.count-1))
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
                var offset = powerProfile.startts!.timeIntervalSinceDate(endts!) - sampleRate
                //println("offset: \(offset), powerProfile.startts: \(powerProfile.startts!), endts: \(endts!)")
                if (offset > 0) {
                    for _ in 1...Int(offset) { data.append(nil) }
                    offset = 0
                }
                let skip = Int(-offset)
                if (skip < powerProfile.v.count) {
                    for index in skip..<powerProfile.v.count { data.append(powerProfile.v[index]) }
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

    private struct Constants {
        static let timestampFormatString = "yyMMddHHmmss's'"
    }
    
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
        case "startts": if inHeader { startts = PowerProfile.powerMeterDateFormatter.dateFromString(input) }
        case "endts": if inHeader { endts = PowerProfile.powerMeterDateFormatter.dateFromString(input) }
        default: break
        }
    }
    
    static let powerMeterDateFormatter: NSDateFormatter = {
        var formatter = NSDateFormatter()
        formatter.dateFormat = Constants.timestampFormatString
        return formatter
    }()
    
    class func timestampFromDate(date: NSDate?) -> String {
        if let date = date {
            return powerMeterDateFormatter.stringFromDate(date)
        }
        return "0"
    }

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
