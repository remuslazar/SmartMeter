//
//  GraphViewController.swift
//  SmartMeter
//
//  Created by Remus Lazar on 20.06.15.
//  Copyright (c) 2015 Remus Lazar. All rights reserved.
//

import UIKit

class GraphViewController: UIViewController {

    var powerGraphEngine: PowerGraphEngine?
    
    var history: PowerMeter.History! {
        didSet {
            if history != nil {
                powerGraphEngine = PowerGraphEngine(history: history)
                graphView?.datasource = powerGraphEngine
                view.setNeedsDisplay()
            }
        }
    }
    
    @IBOutlet weak var graphView: GraphView! {
        didSet {
            graphView.datasource = powerGraphEngine
            graphView.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: "zoom:"))
            graphView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: "pan:"))
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: "doubleTap:")
            tapGestureRecognizer.numberOfTapsRequired = 2
            graphView.addGestureRecognizer(tapGestureRecognizer)
        }
    }

    func doubleTap(gesture: UITapGestureRecognizer) {
        switch gesture.state {
        case .Ended:
            powerGraphEngine?.scaleX = 1.0
            graphView.setNeedsDisplay()
        default: break
        }
    }
    
    func pan(gesture: UIPanGestureRecognizer) {
        switch (gesture.state) {
        case .Changed:
            if powerGraphEngine != nil {
                let translation = gesture.translationInView(graphView)
                let samplesPerPoint = CGFloat(powerGraphEngine!.graphViewgetSampleCount()) / graphView.bounds.width
                powerGraphEngine?.offsetX -= Int(translation.x * samplesPerPoint)
                gesture.setTranslation(CGPointZero, inView: graphView)
                graphView.setNeedsDisplay()
            }
        default: break
        }
    }
    
    func zoom(gesture: UIPinchGestureRecognizer) {
        switch (gesture.state) {
        case .Changed:
            // we want to consider direction of the pinch to determine if we want to
            // scale in the x or/and y direction
            if gesture.numberOfTouches() >= 2 {
                let fingers = [
                    gesture.locationOfTouch(0, inView: graphView),
                    gesture.locationOfTouch(1, inView: graphView)
                ]
                
                let deltaX = abs(fingers[0].x - fingers[1].x)
                let deltaY = abs(fingers[0].y - fingers[1].y)
                let scale = 1.0 - gesture.scale
                let scaleX = 1.0 - deltaX / (deltaX + deltaY) * scale
                let scaleY = 1.0 - deltaY / (deltaX + deltaY) * scale
                
                gesture.scale = 1.0
                
                powerGraphEngine?.maxY /= Double(scaleY)
                
                powerGraphEngine?.scaleX *= Double(scaleX)
                
                graphView.setNeedsDisplay()
            }
            
        default: break
        }
    }

    func updateGraph() { graphView.setNeedsDisplay() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

}
