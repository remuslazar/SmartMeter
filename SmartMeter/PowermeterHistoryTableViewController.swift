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
    
    private let dateFormatter: NSDateFormatter = {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateStyle = NSDateFormatterStyle.ShortStyle
        dateFormatter.timeStyle = NSDateFormatterStyle.MediumStyle
        return dateFormatter
    }()
    
    private let decimalNumberFormatter: NSNumberFormatter = {
        let formatter = NSNumberFormatter()
        formatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
        return formatter
    }()
    
    // MARK: - Table view data source

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete method implementation.
        // Return the number of rows in the section.
        return history?.count ?? 0
    }

    private struct Storyboard {
        static let CellReuseIdentifier = "HistoryCell"
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(Storyboard.CellReuseIdentifier, forIndexPath: indexPath) 

        // Configure the cell...
        if let sample = history?.getSample(indexPath.row) {
            cell.textLabel?.text = dateFormatter.stringFromDate(sample.timestamp)
            cell.detailTextLabel?.text = sample.value != nil
                ? decimalNumberFormatter.stringFromNumber(NSNumber(integer: sample.value!))?.stringByAppendingString("W")
                : "-"
        }

        return cell
    }

}
