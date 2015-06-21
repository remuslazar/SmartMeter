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

private struct Storyboard {
    static let ShowDeviceInfoSegueIdentifier = "ShowDeviceInfo"
    static let ShowHistorySegueIdentifier = "ShowHistory"
    static let GraphViewSegueIdentifier = "MiniGraph"
}

class WattageViewController: UIViewController, PowerMeterDelegate {

    // MARK: - Outlets
    @IBOutlet weak var wattageLabel: UILabel!
    @IBOutlet weak var statusBottomLabel: UILabel!
    
    @IBOutlet weak var bottomBarSpinner: UIActivityIndicatorView!
    @IBAction func rewindButton(sender: UIBarButtonItem) {
        sender.enabled = false
        bottomBarSpinner.startAnimating()
        statusBottomLabel.hidden = true
        powerMeter?.readHistoricalValues {
            sender.enabled = true
            self.bottomBarSpinner.stopAnimating()
            self.statusBottomLabel.hidden = false
            self.updateUI()
        }
    }
    
    weak var graphVC: GraphViewController?
    
    // MARK: - Private data and methods
    private var powerMeter: PowerMeter?
    private var smartMeterHostname: String? {
        didSet {
            if smartMeterHostname != oldValue && smartMeterHostname != nil {
                powerMeter = PowerMeter(host: smartMeterHostname!)
                powerMeter?.delegate = self
                graphVC?.history = powerMeter?.history
            }
        }
    }
    
    private func updateUI() {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateStyle = NSDateFormatterStyle.NoStyle
        dateFormatter.timeStyle = NSDateFormatterStyle.ShortStyle
        if let hist = powerMeter?.history where hist.startts != nil {
            statusBottomLabel.text = "\(hist.count) Samples, \(dateFormatter.stringFromDate(hist.startts!)) - \(dateFormatter.stringFromDate(hist.endts!))"
        } else {
            statusBottomLabel.text = nil
        }
        graphVC?.updateGraph()
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
    
    // MARK: - PowerMeterDelegate
    func didUpdateWattage(currentWattage: Int) {
        self.wattageLabel.text = "\(currentWattage) W"
        updateUI()
    }

    // MARK: - ViewController Lifetime
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
        powerMeter?.stopUpdatingCurrentWattage()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readUserDefaults()
        // listen for changes in the app settings and handle it
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("readUserDefaults"),
            name: NSUserDefaultsDidChangeNotification,
            object: nil)
        updateUI()
    }
   
    // MARK: - Segue
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        switch (segue.identifier!) {

        case Storyboard.ShowDeviceInfoSegueIdentifier:
            if let powerMeterInfoTCC = segue.destinationViewController as? PowerMeterInfoTableViewController {
                powerMeterInfoTCC.powerMeter = self.powerMeter
            }

        case Storyboard.ShowHistorySegueIdentifier:
            if let historyTVC = segue.destinationViewController as? PowermeterHistoryTableViewController {
                historyTVC.history = powerMeter?.history
            }
            
        case Storyboard.GraphViewSegueIdentifier:
            if let vc = segue.destinationViewController as? GraphViewController {
                self.graphVC = vc
            }
            
        default: break
        }
    }

    // MARK: - deinit
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
}
