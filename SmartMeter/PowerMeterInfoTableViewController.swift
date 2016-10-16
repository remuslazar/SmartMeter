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
    @IBOutlet weak var serialNumberLabel: UILabel!

    @IBAction func refresh(_ sender: AnyObject) { updateDeviceInfo() }
    
    // MARK: - public API
    
    var powerMeter: PowerMeter?
    var deviceInfo: [String: String]? { didSet { updateUI() } }

    private func updateUI() {
        hostnameLabel.text = self.powerMeter?.host
        nameLabel.text = deviceInfo?["friendlyName"] ?? "-"
        modelNumberLabel.text = deviceInfo?["modelNumber"] ?? "-"
        serialNumberLabel.text = deviceInfo?["serialNumber"] ?? "-"
        tableView.reloadData()
    }
    
    private func updateDeviceInfo() {
        deviceInfo = nil // invalidate old staled data
        powerMeter?.readDeviceInfo {
            if let info = $0 {
                DispatchQueue.main.async {
                    self.refreshControl?.endRefreshing()
                    self.deviceInfo = info
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        refreshControl?.beginRefreshing()
        updateDeviceInfo()
    }

}
