//
//  PowerMeterInfoTableViewController.swift
//  SmartMeter
//
//  Created by Remus Lazar on 20.06.15.
//  Copyright (c) 2015 Remus Lazar. All rights reserved.
//

import UIKit

class PowerMeterInfoTableViewController: UITableViewController {

    // MARK: - Outlets
    
    @IBOutlet weak var hostnameLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var modelNumberLabel: UILabel!
    @IBOutlet weak var SerialNumberLabel: UILabel!
    
    // MARK: - public API
    
    var powerMeter: PowerMeter?
    
    private func updateUI() {
        self.hostnameLabel.text = self.powerMeter?.host
        self.nameLabel.text = deviceInfo["friendlyName"]
        self.modelNumberLabel.text = deviceInfo["modelNumber"]
        self.SerialNumberLabel.text = deviceInfo["serialNumber"]
    }
    
    var deviceInfo = [String: String]() {
        didSet {
            updateUI()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // we will crash now if powerMeter wasnt set accordingly, which is fine
        //powerMeter = PowerMeter(host: "192.168.37.20")

        powerMeter?.readDeviceInfo {
            if let info = $0 {
                self.deviceInfo = info
            }
        }
    }

}
