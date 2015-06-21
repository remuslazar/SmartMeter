//
//  GraphViewController.swift
//  SmartMeter
//
//  Created by Remus Lazar on 20.06.15.
//  Copyright (c) 2015 Remus Lazar. All rights reserved.
//

import UIKit

class GraphViewController: UIViewController, GraphViewDatasource {

    func graphViewgetSampleCount() -> Int {
        return history?.count ?? 0
    }
    
    func graphViewgetSample(x: Int, resample: Int) -> PowerMeter.History.PowerSample? {
        if history != nil {
            if resample == 1 { return history!.getSample(x) }
            return history!.getSample(x, resample: resample)
        }
        return nil
    }
    
    var history: PowerMeter.History? {
        didSet { view.setNeedsDisplay() }
    }
    
    @IBOutlet weak var graphView: GraphView! {
        didSet {
            graphView.datasource = self
            graphView.addGestureRecognizer(
                UIPinchGestureRecognizer(target: graphView, action: "zoom:")
            )
        }
    }
    
    func updateGraph() { graphView.setNeedsDisplay() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

}
