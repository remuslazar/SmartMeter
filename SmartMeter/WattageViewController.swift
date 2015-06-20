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

class WattageViewController: UIViewController {

    @IBOutlet weak var wattageLabel: UILabel!
    
    var powerMeter: PowerMeter?
    var lastRequestStillPending = false
    
    var timer: NSTimer?
    
    func update() {
        if lastRequestStillPending { return }
        lastRequestStillPending = true
        powerMeter?.readCurrentWattage {
            self.lastRequestStillPending = false
            if let value = $0 {
                println("update: \(value) W")
                self.wattageLabel.text = "\(value) W"
            }
        }
    }
    
    func readUserDefaults() {
        println("readUserDefaults() called")
        if let hostname = NSUserDefaults().valueForKey(UserDefaults.SmartmeterHostname) as? String {
            powerMeter = PowerMeter(host: hostname)
            if NSUserDefaults().valueForKey(UserDefaults.SmartmeterRefreshRate) == nil {
                NSUserDefaults().setValue(2.0, forKey: UserDefaults.SmartmeterRefreshRate)
                NSUserDefaults().synchronize()
            }
            setupTimer()
        }
    }
    
    private func setupTimer() {
        timer?.invalidate()
        if let refreshRate = NSUserDefaults().valueForKey(UserDefaults.SmartmeterRefreshRate) as? Double {
            timer = NSTimer.scheduledTimerWithTimeInterval(NSTimeInterval(refreshRate), target: self, selector: Selector("update"),
                userInfo: nil, repeats: true)
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if NSUserDefaults().valueForKey(UserDefaults.SmartmeterHostname) == nil {
            UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
        }
        setupTimer()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        println("viewWillDisappear() called")
        super.viewDidDisappear(animated)
        timer?.invalidate()
        timer = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("readUserDefaults"),
            name: NSUserDefaultsDidChangeNotification,
            object: nil)
        readUserDefaults()
        update()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}

