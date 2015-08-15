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
    static let SmartmeterPricePerKWh = "smartmeter_price_kwh"
}

private struct Storyboard {
    static let ShowDeviceInfoSegueIdentifier = "ShowDeviceInfo"
    static let ShowHistorySegueIdentifier = "ShowHistory"
    static let GraphViewSegueIdentifier = "MiniGraph"
}

class WattageViewController: UIViewController, PowerMeterDelegate, GraphViewDelegate {
    
    private lazy var currencyFormatter: NSNumberFormatter = {
        let formatter = NSNumberFormatter()
        formatter.numberStyle = .CurrencyStyle
        return formatter
    }()
    
    private struct Labels {
        static let ActionSheetTitle = "Load Historical Data"
        static let ActionSheetMessage = "You can access up to about 8 hours of sampled data from the Power Meter"
    }
    
    private var autoUpdate = false {
        didSet {
            if autoUpdate {
                powerMeter?.startUpdatingCurrentWattage()
                wattageLabel.hidden = false
            } else {
                powerMeter?.stopUpdatingCurrentWattage()
                wattageLabel.hidden = true
            }
        }
    }

    func graphViewDidUpdateDraggedArea(#powerAvg: Double, timespan: Double) {
        let energy = powerAvg * timespan / 3600 // Wh
        let formatter = NSNumberFormatter()
        formatter.maximumFractionDigits = 1
        if let powerAvgText = formatter.stringFromNumber(NSNumber(double: powerAvg)),
            let energyText = formatter.stringFromNumber(NSNumber(double: energy)) {
                statusBottomLabel.text = "\(powerAvgText)W, \(energyText)Wh"
                if pricePerKWh > 0 {
                    statusBottomLabel.text! +=
                    " (\(currencyFormatter.stringFromNumber(NSNumber(double: pricePerKWh * energy / 1000))!))"
                }
        }
    }
    
    // embedded GraphViewController
    weak var graphVC: GraphViewController!
    
    // MARK: - Outlets
    @IBOutlet weak var wattageLabel: UILabel!
    @IBOutlet weak var statusBottomLabel: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!
    
    // MARK: - Bar Buttons
    @IBOutlet weak var pauseButton: UIBarButtonItem!
    @IBOutlet weak var playButton: UIBarButtonItem!
    @IBOutlet weak var calcButton: UIBarButtonItem!
    
    @IBAction func pause(sender: AnyObject) { state = .paused }
    @IBAction func play(sender: AnyObject) { state = .liveView }
    @IBAction func calc(sender: AnyObject) { state = .dragArea }
    
    private enum UIState {
        case liveView
        case paused
        case dragArea
        case loadingHistory
    }
    
    private var state = UIState.liveView {
        didSet {
            switch state {
            case .liveView:
                pauseButton.enabled = true
                playButton.enabled = false
                calcButton.enabled = true
                graphVC.calculateAreaOnPanMode = false
                autoUpdate = true
                
            case .paused:
                pauseButton.enabled = false
                playButton.enabled = true
                calcButton.enabled = true
                graphVC.calculateAreaOnPanMode = false
                autoUpdate = false
                
            case .dragArea:
                pauseButton.enabled = true
                playButton.enabled = true
                calcButton.enabled = false
                graphVC.calculateAreaOnPanMode = true
                statusBottomLabel.text = "Drag on the graph to select an area"
                autoUpdate = false
                
            case .loadingHistory:
                pauseButton.enabled = false
                playButton.enabled = false
                calcButton.enabled = false
                autoUpdate = false
            }
        }
    }
    
    @IBAction func showActionsheet(sender: AnyObject) {
        let sheet = UIAlertController(
            title: Labels.ActionSheetTitle,
            message: Labels.ActionSheetMessage,
            preferredStyle: UIAlertControllerStyle.ActionSheet
        )
        if progressBar.hidden {
            for timespan in [5,15,60,120] {
                sheet.addAction(UIAlertAction(title: "\(timespan) minutes (\(timespan * 60) samples)",
                    style: .Default, handler: { (_) in
                        self.loadHistory(timespan: NSTimeInterval(timespan * 60))
                }))
            }
            sheet.addAction(UIAlertAction(title: "Reset local history",
                style: .Destructive, handler: { (_) in
                    self.powerMeter?.history.purge()
                    self.updateUI()
            }))
        } else {
            sheet.addAction(UIAlertAction(title: "Abort current transfer",
                style: .Destructive, handler: { (_) in
                    if !self.progressBar.hidden {
                        self.powerMeter?.abortCurrentFetchRequest = true
                    }
            }))
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        presentViewController(sheet, animated: true, completion: nil)
    }

    // load historical data from the power meter
    private func loadHistory(timespan: NSTimeInterval = 300) {
        state = .loadingHistory
        self.progressBar.progress = 0
        self.progressBar.hidden = false
        powerMeter?.readSamples(Int(timespan), completionHandler: { (remaining) -> Void in
            self.progressBar.progress = Float(Int(timespan) - remaining) / Float(timespan)
            if (remaining <= 0) {
                self.progressBar.hidden = true
                self.state = .liveView
            }
            self.updateUI()
        })
    }
    
    
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
        if let hist = powerMeter?.history where hist.startts != nil {
            statusBottomLabel.text = "\(hist.count) Samples"
        } else {
            statusBottomLabel.text = nil
        }
        graphVC?.updateGraph()
    }
    
    private var pricePerKWh = 0.0 // in the local currency
    
    func readUserDefaults() {
        println("(re)reading user defaults and init")
        if let hostname = NSUserDefaults().valueForKey(UserDefaults.SmartmeterHostname) as? String {
            smartMeterHostname = hostname
        }
        if let updateInterval = NSUserDefaults().valueForKey(UserDefaults.SmartmeterRefreshRate) as? Double {
            powerMeter?.autoUpdateTimeInterval = NSTimeInterval(updateInterval)
        }
        if let priceString = NSUserDefaults().valueForKey(UserDefaults.SmartmeterPricePerKWh) as? String {
            if let price = NSNumberFormatter().numberFromString(priceString) {
                pricePerKWh = price.doubleValue / 100 // cents
            }
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
        
        autoUpdate = true
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        autoUpdate = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readUserDefaults()
        // listen for changes in the app settings and handle it
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("readUserDefaults"),
            name: NSUserDefaultsDidChangeNotification,
            object: nil)
        updateUI()
        graphVC.graphView.delegate = self
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
