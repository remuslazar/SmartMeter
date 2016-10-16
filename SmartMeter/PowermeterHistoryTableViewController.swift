//
//  PowermeterHistoryTableViewController.swift
//  SmartMeter
//
//  Created by Remus Lazar on 20.06.15.
//  Copyright (c) 2015 Remus Lazar. All rights reserved.
//

import UIKit

class PowermeterHistoryTableViewController: UITableViewController {

    // MARK: - Public API
    
    var history: PowerMeter.History? {
        didSet { tableView.reloadData() }
    }
    
    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = DateFormatter.Style.short
        dateFormatter.timeStyle = DateFormatter.Style.medium
        return dateFormatter
    }()
    
    private let decimalNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = NumberFormatter.Style.decimal
        return formatter
    }()
    
    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete method implementation.
        // Return the number of rows in the section.
        return history?.count ?? 0
    }

    private struct Storyboard {
        static let CellReuseIdentifier = "HistoryCell"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.CellReuseIdentifier, for: indexPath) 

        // Configure the cell...
        if let sample = history?.getSample((indexPath as NSIndexPath).row) {
            cell.textLabel?.text = dateFormatter.string(from: sample.timestamp)
            cell.detailTextLabel?.text = sample.value != nil
                ? (decimalNumberFormatter.string(from: NSNumber(value: sample.value! as Int)))! + "W"
                : "-"
        }

        return cell
    }

}
