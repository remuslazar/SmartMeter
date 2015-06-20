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
    
    func didUpdateWattage(currentWattage: Int) {
        self.wattageLabel.text = "\(currentWattage) W"
    }
    
    func readUserDefaultsAndInitialize() {
        println("(re)reading user defaults and init")
        if let hostname = NSUserDefaults().valueForKey(UserDefaults.SmartmeterHostname) as? String {
            powerMeter = PowerMeter(host: hostname)
            powerMeter?.delegate = self
            
            let interval = NSUserDefaults().valueForKey(UserDefaults.SmartmeterRefreshRate) as? Double ?? 2.0
            powerMeter?.startUpdatingCurrentWattage(NSTimeInterval(interval))
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        // popup the settings bundle if the settings are void
        if NSUserDefaults().valueForKey(UserDefaults.SmartmeterHostname) == nil {
            UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
        }
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        println("viewWillDisappear() called")
        powerMeter?.stopUpdatingCurrentWattage()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readUserDefaultsAndInitialize()
        // listen for changes in the app settings and handle it
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("readUserDefaultsAndInitialize"),
            name: NSUserDefaultsDidChangeNotification,
            object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}

