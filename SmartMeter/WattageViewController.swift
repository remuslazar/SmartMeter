//
//  ViewController.swift
//  SmartMeter
//
//  Created by Remus Lazar on 15.06.15.
//  Copyright (c) 2015 Remus Lazar. All rights reserved.
//

import UIKit

struct UserDefaults {
    static let SmartmeterHostname = "smartmeter_hostname"
    static let SmartmeterRefreshRate = "smartmeter_refresh_rate"
}

class WattageViewController: UIViewController, PowerMeterDelegate {

    @IBOutlet weak var wattageLabel: UILabel!
    
    var powerMeter: PowerMeter?
    var smartMeterHostname: String? {
        didSet {
            if smartMeterHostname != oldValue && smartMeterHostname != nil {
                powerMeter = PowerMeter(host: smartMeterHostname!)
                powerMeter?.delegate = self
            }
        }
    }
    
    func didUpdateWattage(currentWattage: Int) {
        self.wattageLabel.text = "\(currentWattage) W"
    }
    
    func readUserDefaults() {
        println("(re)reading user defaults and init")
        if let hostname = NSUserDefaults().valueForKey(UserDefaults.SmartmeterHostname) as? String {
            smartMeterHostname = hostname
        }
        if let updateInterval = NSUserDefaults().valueForKey(UserDefaults.SmartmeterRefreshRate) as? Double {
            powerMeter?.autoUpdateTimeInterval = NSTimeInterval(updateInterval)
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        // popup the settings bundle if the settings are void
        if NSUserDefaults().valueForKey(UserDefaults.SmartmeterHostname) == nil {
            UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
        }
        
        powerMeter?.startUpdatingCurrentWattage()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        println("viewWillDisappear() called")
        powerMeter?.stopUpdatingCurrentWattage()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readUserDefaults()
        // listen for changes in the app settings and handle it
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("readUserDefaults"),
            name: NSUserDefaultsDidChangeNotification,
            object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}

