//
//  PowerMeter.swift
//  SmartMeter
//
//  Created by Remus Lazar on 15.06.15.
//  Copyright (c) 2015 Remus Lazar. All rights reserved.
//

import Foundation

class PowerMeter {
    
    private let host: String!
    
    func readCurrentWattage(completionHandler: (Int?) -> Void) {
        if let url = NSURL(scheme: "http", host: host, path: "/InstantView/request/getPowerProfile.html") {
            if let u = NSURLComponents(URL: url, resolvingAgainstBaseURL: false) {
                u.queryItems = [
                    NSURLQueryItem(name: "ts", value: "0"),
                    NSURLQueryItem(name: "n", value: "1")
                ]
                PowerProfile.parse(u.URL!) {
                    if let powerProfile = $0 {
                        completionHandler(powerProfile.v.last)
                    }
                }
            }
        }
        completionHandler(nil)
    }
    
    init(host: String) {
        self.host = host
    }
    
}

class PowerProfile : NSObject, Printable, NSXMLParserDelegate {
    var v = [Int]()
    var startts = 0
    
    typealias PowerProfileCompletionHandler = (PowerProfile?) -> Void
    
    private let url: NSURL
    private let completionHandler: PowerProfileCompletionHandler
    
    init(url: NSURL, completionHandler: PowerProfileCompletionHandler) {
        self.url = url
        self.completionHandler = completionHandler
    }
    
    class func parse(url: NSURL, completionHandler: PowerProfileCompletionHandler) {
        PowerProfile(url: url, completionHandler: completionHandler).parse()
    }
    
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

    func parserDidEndDocument(parser: NSXMLParser) { succeed() }
    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) { fail() }
    func parser(parser: NSXMLParser, validationErrorOccurred validationError: NSError) { fail() }

    private var input = ""
    private var inHeader = false
    
    func parser(parser: NSXMLParser, foundCharacters string: String?) {
        input += string!
    }

    private func fail() { complete(success: false) }
    private func succeed() { complete(success: true) }

    private func complete(#success: Bool) {
        dispatch_async(dispatch_get_main_queue()) {
            self.completionHandler(success ? self : nil)
        }
    }
    
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [NSObject : AnyObject]) {
        switch elementName {
        case "header":
            inHeader = true
        default:
            input = ""
        }
    }
    
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "header": inHeader = false
        case "v":
            if !inHeader, let value = NSNumberFormatter().numberFromString(input)?.integerValue {
                v.append(value)
            }
        case "startts":
            if inHeader, let value = NSNumberFormatter().numberFromString(input)?.integerValue {
                startts = value
            }
        default:
            input = ""
        }
    }
    
}

