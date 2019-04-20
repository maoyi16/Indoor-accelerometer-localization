//
//  MapViewController.swift
//  ACC
//
//  Created by Hung-Yun Liao on 6/8/16.
//  Copyright © 2016 Hung-Yun Liao. All rights reserved.
//

import UIKit


class MapViewController: UIViewController, DataProcessorDelegate {
    
    // MARK: Model
    var dataSource: DataProcessor? = nil
    var origin = ThreeAxesSystem<Double>(x: 0, y: 0, z: 0)
    
    // MARK: PublicDB used to pass the object of DataProcessor
    var publicDB = UserDefaults.standard
    
    // MARK: Multi-views declaration
    @IBOutlet weak var gradientView: GradientView!
    @IBOutlet weak var gridView: GridView!
    @IBOutlet weak var mapView: MapView! {
        didSet {
            
            // add pinch gesture recog
            mapView.addGestureRecognizer(UIPinchGestureRecognizer(
                target: self, action: #selector(MapViewController.changeScale(recognizer:))
                ))
            
            // add swipe gestures recog
            let rightSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(MapViewController.moveScreenToRight))
            rightSwipeGestureRecognizer.direction = .right
            mapView.addGestureRecognizer(rightSwipeGestureRecognizer)
            
            let upSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(MapViewController.moveScreenToUp))
            upSwipeGestureRecognizer.direction = .up
            mapView.addGestureRecognizer(upSwipeGestureRecognizer)
            
            let downSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(MapViewController.moveScreenToDown))
            downSwipeGestureRecognizer.direction = .down
            mapView.addGestureRecognizer(downSwipeGestureRecognizer)
            
            let leftSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(MapViewController.moveScreenToLeft))
            leftSwipeGestureRecognizer.direction = .left
            mapView.addGestureRecognizer(leftSwipeGestureRecognizer)
            
        }
    }
    
    /* MARK: Gesture Functions */
    var pinchScale: CGFloat = 1
    
    @objc func changeScale(recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .changed, .ended:
            pinchScale *= recognizer.scale
            pinchScale = toZeroPointFiveMultiples(x: pinchScale) // let pinchScale always be the multiples of 0.5 to keep the textLayer clean.
            
            if pinchScale == 0 { // restrict the minimum scale to 0.5 instead of 0, otherwise the scale will always be 0 afterwards.
                pinchScale = 0.5
            }
            
            let times = pinchScale/CGFloat(gridView.scaleValueForTheText)
            
            if gridView.scaleValueForTheText != 0.5 || pinchScale != 0.5 {
                mapView.setScale(scale: Double(1/times))
            }
            
            gridView.setScale(scale: Double(pinchScale))
            recognizer.scale = 1
        default:
            break
        }

    }
    
    var shiftedBySwipe = ThreeAxesSystem<Double>(x:0, y:0, z:0)
    let shiftAmount: Double = 20
    
    @objc func moveScreenToRight() {
        shiftedBySwipe.x += shiftAmount
        origin.x += shiftAmount
        setOrigin(x: origin.x, y: origin.y)
    }
    
    @objc func moveScreenToUp() {
        shiftedBySwipe.y -= shiftAmount
        origin.y -= shiftAmount
        setOrigin(x: origin.x, y: origin.y)
    }
    
    @objc func moveScreenToDown() {
        shiftedBySwipe.y += shiftAmount
        origin.y += shiftAmount
        setOrigin(x: origin.x, y: origin.y)
    }
    
    @objc func moveScreenToLeft() {
        shiftedBySwipe.x -= shiftAmount
        origin.x -= shiftAmount
        setOrigin(x: origin.x, y: origin.y)
    }
    
    // MARK: Outlets
    @IBOutlet weak var accX: UILabel!
    @IBOutlet weak var accY: UILabel!
    @IBOutlet weak var velX: UILabel!
    @IBOutlet weak var velY: UILabel!
    @IBOutlet weak var disX: UILabel!
    @IBOutlet weak var disY: UILabel!
    
    @IBOutlet weak var rotX: UILabel!
    
    @IBAction func cleanpath(sender: UIButton) {
        mapView?.cleanPath()
    }
    
    private func setOrigin(x: Double, y: Double) {
        gridView?.setOrigin(x: x, y: y)
        mapView?.setOrigin(x: x, y: y)
    }
    
    private func updateUIWithGivenFrame(originX: CGFloat, originY: CGFloat, width: CGFloat, height: CGFloat) {
        // All view are set based on the "gradientView" (background)
        gradientView.frame = CGRect(x: originX, y: originY, width: width, height: height)
        gridView.frame = gradientView.frame
        mapView.frame = gradientView.frame
        (origin.x, origin.y) = (Double(gradientView.frame.midX) + shiftedBySwipe.x, Double(gradientView.frame.midY) + shiftedBySwipe.y)
        setOrigin(x: origin.x, y: origin.y)
    }
    
    // MARK: Override functions
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(receiveDataSource(notification:)), name:NSNotification.Name(rawValue: "dataSource"), object: nil)
        
        // Objects setup
        gradientView.colorSetUp(topColor: UIColor.white.cgColor, bottomColor: UIColor.cyan.withAlphaComponent(0.5).cgColor)
        
        gridView.backgroundColor = UIColor.clear
        gridView.setScale(scale: 1.0)
        
        mapView.backgroundColor = UIColor.clear
        mapView.setScale(scale: 1.0)
        
        updateUIWithGivenFrame(originX: view.frame.origin.x, originY: view.frame.origin.y, width: view.frame.width, height: view.frame.height)
    }
    
    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        if UIDevice.current.orientation.isLandscape {
            // Landscape orientation
            if mapView != nil {
                updateUIWithGivenFrame(originX: view.frame.origin.x, originY: view.frame.origin.y, width: view.frame.height, height: view.frame.width)
            }
     } else {
            // Portrait orientation
            if mapView != nil {
                updateUIWithGivenFrame(originX: view.frame.origin.x, originY: view.frame.origin.y, width: view.frame.height, height: view.frame.width)
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        dataSource?.delegate = self
    }
    
    // MARK: Notification center functions
    @objc func receiveDataSource(notification: NSNotification) {
        if let source = notification.object as? DataProcessor {
            dataSource = source
            dataSource!.startsDetection()
        }
    }
    
    // MARK: Delegate
    func sendingNewData(person: DataProcessor, type: speedDataType, data: ThreeAxesSystemDouble) {
        switch type {
        case .accelerate:
            accX.text = "\(roundNum(number: Double(data.x)))"
            accY.text = "\(roundNum(number: Double(data.y)))"
        case .velocity:
            velX.text = "\(roundNum(number: Double(data.x)))"
            velY.text = "\(roundNum(number: Double(data.y)))"
        case .distance:
            let magnify = 20.0 // this var is used to make the movement more observable. Basically, if the scale of the map is 1, then magnify should be 20. if 2, then 40.
            mapView.movePointTo(x: Double(data.x) * magnify, y: Double(data.y) * magnify)
            disX.text = "\(roundNum(number: Double(data.x)))"
            disY.text = "\(roundNum(number: Double(data.y)))"
        case .rotation:
            //rotX.text = "\(roundNum(Double(data.pitch)))"
            break
        }
    }
    
    func sendingNewStatus(person: DataProcessor, status: String) {
        // intentionally left blank in order to conform to the protocol
    }
    
    func sendingAltitude(data: Double) {
        print("Altitude change", data)
    }
    
    func sendingFloorChange(source: FloorChangeSource, change: Int) {
        print("Detected floor change", change, "from", source)
    }
}
