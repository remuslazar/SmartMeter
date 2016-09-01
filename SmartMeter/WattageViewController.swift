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
        static let ActionSheetTitle = NSLocalizedString(
            "Load Historical Data",
            comment: "ActionSheet label for loading historical data from the powermeter."
        )
        static let ActionSheetMessage = NSLocalizedString(
            "You can access up to about 8 hours of sampled data from the Power Meter",
            comment: "ActionSheet description telling the user about the available history size and options."
        )
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

    func graphViewDidUpdateDraggedArea(powerAvg powerAvg: Double, timespan: Double) {
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
                wattageLabel.text = nil
                
            case .dragArea:
                pauseButton.enabled = true
                playButton.enabled = true
                calcButton.enabled = false
                graphVC.calculateAreaOnPanMode = true
                statusBottomLabel.text = NSLocalizedString("Drag on the graph to select an area",
                    comment: "Status label text to inform the user about viable options available in this particular mode")
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
        
        if let ppc = sheet.popoverPresentationController, button = sender as? UIBarButtonItem {
            ppc.barButtonItem = button
        }
        
        if progressBar.hidden {
            for timespan in [1, 5,15,60,120] {
                sheet.addAction(UIAlertAction(title: String.localizedStringWithFormat(
                    NSLocalizedString("%d minute(s)",
                        comment: "ActionSheet label for the selection of the time span in minutes"
                    ),
                    timespan),
                    style: .Default, handler: { (_) in
                        self.loadHistory(NSTimeInterval(timespan * 60))
                }))
            }
            sheet.addAction(UIAlertAction(title: NSLocalizedString("Reset local history",
                comment: "ActionSheet label to reset te history"),
                style: .Destructive, handler: { (_) in
                    self.powerMeter?.history.purge()
                    self.updateUI()
            }))
        } else {
            sheet.addAction(UIAlertAction(title: NSLocalizedString("Abort current transfer",
                comment: "ActionSheet label to abort the current transfer"),
                style: .Destructive, handler: { (_) in
                    if !self.progressBar.hidden {
                        self.powerMeter?.abortCurrentFetchRequest = true
                    }
            }))
        }
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "ActionSheet cancel label"),
            style: .Cancel, handler: nil))
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
            statusBottomLabel.text = String.localizedStringWithFormat(
                NSLocalizedString("%d sample(s)", comment: "Status label about the current sample count"), hist.count)
        } else {
            statusBottomLabel.text = nil
        }
        graphVC?.updateGraph()
    }
    
    private var pricePerKWh = 0.0 // in the local currency
    
    func readUserDefaults() {
        print("(re)reading user defaults and init")
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
    
    func didEnterBackground() {
        print("autoUpdate disabled while running in background")
        state = .paused
    }

    // MARK: - PowerMeterDelegate
    func didUpdateWattage(currentWattage: Int?) {
        self.wattageLabel.text = currentWattage != nil ? String.localizedStringWithFormat("%d W", currentWattage!) : nil
        updateUI()
    }
    
    func powerMeterUpdateWattageDidFail() {
        let alert = UIAlertController(title: NSLocalizedString("Network Error", comment: "Alert title when a network error occur"),
            message: String.localizedStringWithFormat(
                NSLocalizedString(
                    "The PowerMeter device (Hostname: %@) cannot be accessed over the Network. Check your settings or connectivity.", comment: "Alert Message telling the user that the PowerMetter cannot be accessed over the Network"),
            self.powerMeter!.host),
            preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK label in the Network Error Alert")
            , style: UIAlertActionStyle.Default, handler: nil))
        presentViewController(alert, animated: true, completion: nil)
        state = .paused
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
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readUserDefaults()
        // listen for changes in the app settings and handle it
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(WattageViewController.readUserDefaults),
            name: NSUserDefaultsDidChangeNotification,
            object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(WattageViewController.didEnterBackground),
            name: UIApplicationDidEnterBackgroundNotification, object: nil)
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
