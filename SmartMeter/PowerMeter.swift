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
    func didUpdateWattage(currentWattage: Int?)
    func powerMeterUpdateWattageDidFail()
}

class PowerMeter: NSObject {
    
    enum Error : ErrorType {
        case GenericFailure
    }
    
    // MARK: - public API
    
    init(host: String) { self.host = host }

    let host: String!
    var delegate: PowerMeterDelegate?
    var history = History(size: 300) // historical data for 5 minutes
    
    // abort the current fetch request
    var abortCurrentFetchRequest = false
    
    // read power samples from the power meter and append them to the history data
    // the maximum batch size supported by the device is currently 100, which is also the default
    func readSamples(num: Int, batchSize: Int = 100, completionHandler: (remaining: Int) -> Void) {
        readSamples {
            let remaining = max( 0, num - batchSize)
            if self.abortCurrentFetchRequest {
                completionHandler(remaining: 0)
                self.abortCurrentFetchRequest = false
            } else {
                completionHandler(remaining: remaining)
                if remaining > 0 {
                    self.readSamples(remaining, completionHandler: completionHandler)
                }
            }
        }
    }

    // read the device info from the power meter asynchronously
    // will call the callback in the main queue
    func readDeviceInfo(completionHandler: ([String: String]?) -> Void) {
        let u = NSURLComponents()
        u.scheme = "http"
        u.host = host
        u.path = "/wikidesc.xml"
        PowerMeterDeviceInfo.parse(u.URL!) {
            if let deviceInfo = $0 as? PowerMeterDeviceInfo {
                //println("readDeviceInfo: \(deviceInfo)")
                completionHandler(deviceInfo.info)
            } else {
                completionHandler(nil)
            }
        }
    }
    
    // MARK: - private
    
    // internal function to read one batch of data from the power meter
    private func readSamples(count: Int = 100, completionHandler: () -> Void) {
        // e.g. startts = 01.01.2015 10:22:33 we need to read data until
        //                01.01.2015 10:22:32
        let lastTimestamp = history.startts?.dateByAddingTimeInterval(-1)
        readPowerProfile(numSamples: count, lastts: lastTimestamp) {
            _ = $1 // don't care about errors right now
            if let powerProfile = $0 {
                let remainingCapacity = self.history.size - self.history.count
                if remainingCapacity < powerProfile.v.count {
                    self.history.size += powerProfile.v.count - remainingCapacity
                }
                self.history.prepend(powerProfile)
            }
            completionHandler()
        }
    }
    
    // calculate the internal RTC value of the power meter, including the current drift
    private func powerMeterRTC() -> NSDate? {
        if let skew = timeSkew {
            return NSDate().dateByAddingTimeInterval(skew)
        }
        return nil
    }
    
    // read the current wattage from the power meter asynchronously
    // will call the callback in the main queue
    private func readCurrentWattage(initialSamples: Int = 2, completionHandler: (Int?, Error?) -> Void) {
        
        var numSamples = initialSamples
        
//        print("History endts=\(self.history.endts)")
        
        // calculate how many samples we need from last request
        if let powermeterNow = powerMeterRTC(),
            let endts = self.history.endts  {
                let count = powermeterNow.timeIntervalSinceDate(endts)
                numSamples = Int(count) + 2
        }
        
        var lastts: NSDate?
        
        
        if (numSamples > 600) { // more than 10 minutes running in background
            // dont fetch the history for this long period of time. Else, reinit the history
            history.purge()
            numSamples = initialSamples
        }
        
        if (numSamples > 100) {
            numSamples = 100
            lastts = history.endts?.dateByAddingTimeInterval(NSTimeInterval(numSamples))
        }

//        print("readCurrentWattage(), numSamples=\(numSamples), lastts=\(lastts)")

        readPowerProfile(numSamples: numSamples, lastts: lastts) {
            if let powerProfile = $0 {
//                print("got powerProfile \(powerProfile.startts!)-\(powerProfile.endts!)")
                self.history.add(powerProfile)

                if (lastts == nil) {
                    completionHandler(powerProfile.v.last, nil)
                    self.timeSkew = powerProfile.endts?.timeIntervalSinceNow
                } else {
                    // because when lastts != nil, we know that the last sample
                    // is not the current one. So we supply nil as the current value
                    completionHandler(nil, nil)
                }
            } else if let error = $1 {
                completionHandler(nil, error)
            }
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
    
    func isCurrentlyUpdatingCurrentWattage() -> Bool {
        return timer != nil && timer!.valid
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

    // time skew of the power meter device (negative means that the device RTC is late)
    private var timeSkew: NSTimeInterval?

    func update() {
        if delegate == nil || lastRequestStillPending { return }
        lastRequestStillPending = true
        readCurrentWattage {
            self.lastRequestStillPending = false
            if let _ = $1 { // error
                self.delegate?.powerMeterUpdateWattageDidFail()
            } else {
                self.delegate?.didUpdateWattage($0)
            }
        }
    }
    
    // generic function to read a specific power profile from the power meter
    private func readPowerProfile(numSamples numSamples: Int, lastts: NSDate?, completionHandler: (PowerProfile?, Error?) -> Void) {
        let u = NSURLComponents()
        u.scheme = "http"
        u.host = host
        u.path = "/InstantView/request/getPowerProfile.html"
        u.queryItems = [
            NSURLQueryItem(name: "ts", value: PowerProfile.timestampFromDate(lastts)),
            NSURLQueryItem(name: "n", value: "\(numSamples)")
        ]
        PowerProfile.parse(u.URL!) {
            if let powerProfile = $0 as? PowerProfile {
                completionHandler(powerProfile, nil)
            } else {
                completionHandler(nil, .GenericFailure)
            }
        }
    }
    
    // MARK: - PowerMeter.History class
    
    class History {

        init(size newSize: Int) {
            self.size = newSize
        }
        
        func purge() {
            data.removeAll(keepCapacity: false)
            startts = nil
        }
        
        struct PowerSample {
            let timestamp: NSDate
            let value: Int?
        }

        private var data = [Int?]()

        // size in num samples (seconds)
        var size: Int { didSet { trim() } }
        let sampleRate = 1.0 // in seconds
        var startts: NSDate?
        
        var endts: NSDate? {
            return startts?.dateByAddingTimeInterval(Double(data.count-1))
        }
        
        var count: Int {
            return data.count
        }
        
        func getSample(index: Int) -> PowerSample? {
            if startts != nil && index < data.count {
                return PowerSample(
                    timestamp: startts!.dateByAddingTimeInterval(Double(index) * sampleRate),
                    value: data[index]
                )
            }
            return nil
        }
        
        func getSample(index: Int, resample: Int) -> PowerSample? {
            if let sample = getSample(index) {
                var sum: Int = 0
                var count = 0
                for i: Int in 0..<resample {
                    if data.count == index+i { break }
                    if let val = data[index+i]?.value {
                        sum += Int(val)
                        count += 1
                    }
                }
                if count == 0 { return sample }
                return PowerSample(timestamp: sample.timestamp, value: Int(round(Double(sum) / Double(count))))
            }
            return nil
        }
        
        // trim the data to not exceed the size constraint
        private func trim() {
            let count = self.count - size
            if (count > 0) {
                for _ in 1...count { data.removeAtIndex(0) }
                startts = startts?.dateByAddingTimeInterval(NSTimeInterval(count))
            }
        }
        
        func prepend(powerProfile: PowerProfile) {
            
            // calculate the overlap of the new data with the already existing data
            guard startts != nil else { return }
            
            let overlap = powerProfile.v.count - Int(startts!.timeIntervalSinceDate(powerProfile.startts!))
            
            var newData = [Int?]()
            newData.insertContentsOf(powerProfile.v.map { $0 } , at: 0)
            
            if (overlap > 0) {
                newData.removeRange(newData.count-overlap ..< newData.count)
            } else if (overlap < 0) {
                // fill up the missing values with nil
                newData += [Int?](count: -overlap, repeatedValue: nil)
            } // else overlap == 0, no need to do everything, just insert the data as is
            
            data.insertContentsOf(newData, at: 0)
            startts = startts?.dateByAddingTimeInterval(NSTimeInterval(-newData.count))
            trim()
        }
        
        func add(powerProfile: PowerProfile) {
            if startts == nil {
                startts = powerProfile.startts
                data = powerProfile.v.map { $0 }
            } else {
                var offset = powerProfile.startts!.timeIntervalSinceDate(endts!) - sampleRate
                //println("offset: \(offset), powerProfile.startts: \(powerProfile.startts!), endts: \(endts!)")
                if (offset > 0) {
                    print("\(offset) nil values")
                    for _ in 1...Int(offset) { data.append(nil) }
                    offset = 0
                }
                let skip = Int(-offset)
                if (skip < powerProfile.v.count) {
                    for index in skip..<powerProfile.v.count { data.append(powerProfile.v[index]) }
                }
            }
            trim()
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

    // MARK: - Public API
    
    // data store, all values are Int's
    var v = [Int]()
    
    // start and end timestamps
    var endts: NSDate?
    var startts: NSDate? { // computed property
        return endts?.dateByAddingTimeInterval(NSTimeInterval(-(v.count-1)))
    }
    
    // MARK: - Constants
    private struct Constants {
        static let timestampFormatString = "yyMMddHHmmss"
    }
    
    // MARK: - NSXMLParser Delegate
    
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
        case "v" where !inHeader:
            if let value = NSNumberFormatter().numberFromString(input)?.integerValue {
                v.append(value)
            }
        case "endts" where inHeader:
            endts = PowerProfile.powerMeterDateFormatter.dateFromString(String(input.characters.dropLast()))
        default: break
        }
    }
    
    // MARK: - private data
    
    private static let powerMeterDateFormatter: NSDateFormatter = {
        var formatter = NSDateFormatter()
        formatter.dateFormat = Constants.timestampFormatString
        return formatter
    }()
    
    private class func timestampFromDate(date: NSDate?) -> String {
        if let date = date {
            return powerMeterDateFormatter.stringFromDate(date)
        }
        return "0"
    }

}

// Base class for xml based powermeter data, both PowerProfile and PowerMeterDeviceInfo classes do inherit from this base class
class PowerMeterXMLData : NSObject, NSXMLParserDelegate {
    
    typealias PowerMeterXMLDataCompletionHandler = (PowerMeterXMLData?) -> Void
    private let completionHandler: PowerMeterXMLDataCompletionHandler

    init(url: NSURL, completionHandler: PowerMeterXMLDataCompletionHandler) {
        self.url = url
        self.completionHandler = completionHandler
    }
    
    private let url: NSURL
    private var lastError: ErrorType!
    
    private func parse() {
        let qos = Int(QOS_CLASS_USER_INITIATED.rawValue)
        dispatch_async(dispatch_get_global_queue(qos, 0)) {
            do {
                let data = try NSData(contentsOfURL: self.url, options: NSDataReadingOptions.UncachedRead)
                self.lastError = nil
                let parser = NSXMLParser(data: data)
                parser.delegate = self
                parser.shouldProcessNamespaces = false
                parser.shouldReportNamespacePrefixes = false
                parser.shouldResolveExternalEntities = false
                parser.parse()
            } catch {
                print("error while reading from the power meter: \(error)")
                self.lastError = error
                self.fail()
            }
        }
        
    }

    // helper vars for XML parsing
    private var input = ""
    private var inHeader = false
    
    private func fail() { complete(success: false) }
    private func succeed() { complete(success: true) }

    private func complete(success success: Bool) {
        dispatch_async(dispatch_get_main_queue()) {
            self.completionHandler(success ? self : nil)
        }
    }
    
    // MARK: - NSXMLParser Delegate

    func parserDidEndDocument(parser: NSXMLParser) { succeed() }
    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) { fail() }
    func parser(parser: NSXMLParser, validationErrorOccurred validationError: NSError) { fail() }
    func parser(parser: NSXMLParser, foundCharacters string: String) { input += string }
}
