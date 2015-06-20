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
    var autoUpdateTimeInterval = NSTimeInterval(3) {
        didSet {
            if timer != nil { // update the current timer
                setupTimer()
            }
        }
    }
    
    private func setupTimer() {
        timer?.invalidate()
        timer = NSTimer.scheduledTimerWithTimeInterval(autoUpdateTimeInterval, target: self, selector: Selector("update"),
            userInfo: nil, repeats: true)
    }
    
    let host: String!
    private var lastRequestStillPending = false
    private var timer: NSTimer?
    
    init(host: String) {
        self.host = host
    }
    
    // read the current wattage from the power meter asynchronously
    // will call the callback in the main queue
    func readCurrentWattage(completionHandler: (Int?) -> Void) {
        if let url = NSURL(scheme: "http", host: host, path: "/InstantView/request/getPowerProfile.html") {
            if let u = NSURLComponents(URL: url, resolvingAgainstBaseURL: false) {
                u.queryItems = [
                    NSURLQueryItem(name: "ts", value: "0"),
                    NSURLQueryItem(name: "n", value: "1")
                ]
                PowerProfile.parse(u.URL!) {
                    if let powerProfile = $0 as? PowerProfile{
                        //println("readCurrentWattage: wattage: \(powerProfile.v.last)W, ts: \(powerProfile.startts)")
                        completionHandler(powerProfile.v.last)
                    }
                }
            }
        }
        completionHandler(nil)
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
        }
        completionHandler(nil)
    }

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
    
    func stopUpdatingCurrentWattage() {
        timer?.invalidate()
        timer = nil
    }
    
    func startUpdatingCurrentWattage() {
        update()
        setupTimer()
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
    var startts: String?

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
        case "startts":
            if inHeader {
                startts = input
            }
        default: break
        }
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
            if let parser = NSXMLParser(contentsOfURL: self.url) {
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
