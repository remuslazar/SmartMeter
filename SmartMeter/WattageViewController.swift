//
//  ViewController.swift
//  SmartMeter
//
//  Created by Remus Lazar on 15.06.15.
//  Copyright (c) 2015 Remus Lazar. All rights reserved.
//

import Foundation
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
    
    private lazy var currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
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
                wattageLabel.isHidden = false
            } else {
                powerMeter?.stopUpdatingCurrentWattage()
                wattageLabel.isHidden = true
            }
        }
    }

    func graphViewDidUpdateDraggedArea(powerAvg: Double, timespan: Double) {
        let energy = powerAvg * timespan / 3600 // Wh
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        if let powerAvgText = formatter.string(from: NSNumber(value: powerAvg as Double)),
            let energyText = formatter.string(from: NSNumber(value: energy as Double)) {
                statusBottomLabel.text = "\(powerAvgText)W, \(energyText)Wh"
                if pricePerKWh > 0 {
                    statusBottomLabel.text! +=
                    " (\(currencyFormatter.string(from: NSNumber(value: pricePerKWh * energy / 1000 as Double))!))"
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
    
    @IBAction func pause(_ sender: AnyObject) { state = .paused }
    @IBAction func play(_ sender: AnyObject) { state = .liveView }
    @IBAction func calc(_ sender: AnyObject) { state = .dragArea }
    
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
                pauseButton.isEnabled = true
                playButton.isEnabled = false
                calcButton.isEnabled = true
                graphVC.calculateAreaOnPanMode = false
                autoUpdate = true
                
            case .paused:
                pauseButton.isEnabled = false
                playButton.isEnabled = true
                calcButton.isEnabled = true
                graphVC.calculateAreaOnPanMode = false
                autoUpdate = false
                wattageLabel.text = nil
                
            case .dragArea:
                pauseButton.isEnabled = true
                playButton.isEnabled = true
                calcButton.isEnabled = false
                graphVC.calculateAreaOnPanMode = true
                statusBottomLabel.text = NSLocalizedString("Drag on the graph to select an area",
                    comment: "Status label text to inform the user about viable options available in this particular mode")
                autoUpdate = false
                
            case .loadingHistory:
                pauseButton.isEnabled = false
                playButton.isEnabled = false
                calcButton.isEnabled = false
                autoUpdate = false
            }
        }
    }
    
    @IBAction func showActionsheet(_ sender: AnyObject) {
        let sheet = UIAlertController(
            title: Labels.ActionSheetTitle,
            message: Labels.ActionSheetMessage,
            preferredStyle: UIAlertControllerStyle.actionSheet
        )
        
        if let ppc = sheet.popoverPresentationController, let button = sender as? UIBarButtonItem {
            ppc.barButtonItem = button
        }
        
        if progressBar.isHidden {
            for timespan in [1, 5,15,60,120] {
                sheet.addAction(UIAlertAction(title: String.localizedStringWithFormat(
                    NSLocalizedString("%d minute(s)",
                        comment: "ActionSheet label for the selection of the time span in minutes"
                    ),
                    timespan),
                    style: .default, handler: { (_) in
                        self.loadHistory(timespan: TimeInterval(timespan * 60))
                }))
            }
            sheet.addAction(UIAlertAction(title: NSLocalizedString("Reset local history",
                comment: "ActionSheet label to reset te history"),
                style: .destructive, handler: { (_) in
                    self.powerMeter?.history.purge()
                    self.updateUI()
            }))
        } else {
            sheet.addAction(UIAlertAction(title: NSLocalizedString("Abort current transfer",
                comment: "ActionSheet label to abort the current transfer"),
                style: .destructive, handler: { (_) in
                    if !self.progressBar.isHidden {
                        self.powerMeter?.abortCurrentFetchRequest = true
                    }
            }))
        }
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "ActionSheet cancel label"),
            style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }

    // load historical data from the power meter
    private func loadHistory(timespan: TimeInterval = 300) {
        state = .loadingHistory
        self.progressBar.progress = 0
        self.progressBar.isHidden = false
        powerMeter?.readSamples(num: Int(timespan), completionHandler: { (remaining) -> Void in
            self.progressBar.progress = Float(Int(timespan) - remaining) / Float(timespan)
            if (remaining <= 0) {
                self.progressBar.isHidden = true
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
        if let hist = powerMeter?.history , hist.startts != nil {
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
        if let hostname = Foundation.UserDefaults().value(forKey: UserDefaults.SmartmeterHostname) as? String {
            smartMeterHostname = hostname
        }
        if let updateInterval = Foundation.UserDefaults().value(forKey: UserDefaults.SmartmeterRefreshRate) as? Double {
            powerMeter?.autoUpdateTimeInterval = TimeInterval(updateInterval)
        }
        if let priceString = Foundation.UserDefaults().value(forKey: UserDefaults.SmartmeterPricePerKWh) as? String {
            if let price = NumberFormatter().number(from: priceString) {
                pricePerKWh = price.doubleValue / 100 // cents
            }
        }
    }
    
    func didEnterBackground() {
        print("autoUpdate disabled while running in background")
        state = .paused
    }

    // MARK: - PowerMeterDelegate
    func didUpdateWattage(_ currentWattage: Int?) {
        self.wattageLabel.text = currentWattage != nil ? String.localizedStringWithFormat("%d W", currentWattage!) : nil
        updateUI()
    }
    
    func powerMeterUpdateWattageDidFail() {
        let alert = UIAlertController(title: NSLocalizedString("Network Error", comment: "Alert title when a network error occur"),
            message: String.localizedStringWithFormat(
                NSLocalizedString(
                    "The PowerMeter device (Hostname: %@) cannot be accessed over the Network. Check your settings or connectivity.", comment: "Alert Message telling the user that the PowerMetter cannot be accessed over the Network"),
            self.powerMeter!.host),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK label in the Network Error Alert")
            , style: UIAlertActionStyle.default, handler: nil))
        present(alert, animated: true, completion: nil)
        state = .paused
    }

    // MARK: - ViewController Lifetime
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // popup the settings bundle if the settings are void
        if Foundation.UserDefaults().value(forKey: UserDefaults.SmartmeterHostname) == nil {
            UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
        }
        
        autoUpdate = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readUserDefaults()
        // listen for changes in the app settings and handle it
        NotificationCenter.default.addObserver(self, selector: #selector(WattageViewController.readUserDefaults),
            name: Foundation.UserDefaults.didChangeNotification,
            object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(WattageViewController.didEnterBackground),
            name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        updateUI()
        graphVC.graphView.delegate = self
    }
   
    // MARK: - Segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch (segue.identifier!) {

        case Storyboard.ShowDeviceInfoSegueIdentifier:
            if let powerMeterInfoTCC = segue.destination as? PowerMeterInfoTableViewController {
                powerMeterInfoTCC.powerMeter = self.powerMeter
            }

        case Storyboard.ShowHistorySegueIdentifier:
            if let historyTVC = segue.destination as? PowermeterHistoryTableViewController {
                historyTVC.history = powerMeter?.history
            }
            
        case Storyboard.GraphViewSegueIdentifier:
            if let vc = segue.destination as? GraphViewController {
                self.graphVC = vc
            }
            
        default: break
        }
    }

    // MARK: - deinit
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}
