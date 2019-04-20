//
//  DataProcessor.swift
//  ACC
//
//  Created by Hung-Yun Liao on 6/29/16.
//  Copyright © 2016 Hung-Yun Liao. All rights reserved.
//

import Foundation
import CoreMotion

protocol DataProcessorDelegate {
    func sendingNewData(person: DataProcessor, type: speedDataType, data: ThreeAxesSystemDouble)
    func sendingNewStatus(person: DataProcessor, status: String)
    func sendingFloorChangeSourceData(source: FloorChangeSource, val: Double)
    func sendingFloorChange(source: FloorChangeSource, change: Int)
}

enum FloorChangeSource {
    case altitude
    case acceleration
    case rotation
}

enum speedDataType {
    case accelerate
    case velocity
    case distance
    case rotation
}

class DataProcessor {
    
    // MARK: delegate
    var delegate: DataProcessorDelegate? = nil
    
    func newData(type: speedDataType, sensorData: ThreeAxesSystemDouble) {
        delegate?.sendingNewData(person: self, type: type, data: sensorData)
    }
    
    func newStatus(status: String) {
        delegate?.sendingNewStatus(person: self, status: status)
    }
    
    
    // MARK: test param
//    var test = 0
//    var sum = 0.0
    
    // MARK: System parameters setup
    let gravityConstant = 9.81457
//    let publicDB = UserDefaults.standard
//    var accelerometerUpdateInterval: Double = 0.01
//    var gyroUpdateInterval: Double = 0.01
    var deviceMotionUpdateInterval: Double = 0.01
    let accelerationThreshold = 0.5
//    var staticStateJudgeThreshold = (accModulus: 0.25, gyroModulus: 0.2, modulusDiff: 0.05)
    
//    var calibrationTimeAssigned: Int = 100
    
    // MARK: Instance variables
    var motionManager = CMMotionManager()
//    var accModulusAvg = 0.0
    var accSys: System = System()
    var gyroSys: System = System()
    var absSys: System = System()
    
    // MARK: Kalman Filter
    var arrayOfPoints: [Double] = [1, 2, 3]
    var linearCoef = (slope: 0.0, intercept: 0.0)
    
    // MARK: Refined Kalman Filter
    var arrayForCalculatingKalmanRX = [Double]()
    var arrayForCalculatingKalmanRY = [Double]()
    var arrayForCalculatingKalmanRZ = [Double]()
    
    // MARK: Static judement
//    var staticStateJudge = (modulAcc: false, modulGyro: false, modulDiffAcc: false) // true: static false: dynamic
//    var arrayForStatic = Array<Double>(repeating: -1, count: 7)
//    var index = 0
//    var modulusDiff = -1.0
    
    // MARK: Three-Point Filter
    let numberOfPointsForThreePtFilter = 3
    var arrayX = [Double]()
    var arrayY = [Double]()
    var arrayZ = [Double]()
    
    // MARK: Filter decision
    enum Option {
        case Raw
        case ThreePoint
        case Kalman
    }
    let filterChoice = Option.ThreePoint
    
    // MARK: Performance measure
//    var performanceDataArrayX = [Double]()
//    var performanceDataArrayY = [Double]()
//    var performanceDataArrayZ = [Double]()
//    var count = 1
//    var performanceDataSize = 100
//    var executePerformanceCompare = false
    
    
    // MARK: motion activity manager
    let motionActivityManager = CMMotionActivityManager()
    var is_stationary = true
    
    // MARK: floor change from altitude
    let altimeter = CMAltimeter()
    let altitude_floor_height = 3.0
    var altitude_floor = 0
    
    // MARK: floor change from acceleration
    let velocity_z_upperbound = 5.0
    let velocity_z_lowerbound = 0.1
    var velocity_pending_floor_change = 0
    
    // MARK: floor change from rotation
    var initial_pitch: Double?
    let pitch_upperbound = 20.0
    let pitch_lowerbound = 5.0
    var pitch_pending_floor_change = 0
    
    func startsDetection() {
        
        // Set Motion Manager Properties
//        motionManager.accelerometerUpdateInterval = accelerometerUpdateInterval
//        motionManager.gyroUpdateInterval = gyroUpdateInterval
//        motionManager.startDeviceMotionUpdates()//for gyro degree
        motionManager.deviceMotionUpdateInterval = deviceMotionUpdateInterval
        
        // Recording data
//        motionManager.startAccelerometerUpdates(to: OperationQueue.current!, withHandler: { (accelerometerData: CMAccelerometerData?, NSError) -> Void in
//            self.outputAccData(acceleration: accelerometerData!.acceleration)
//            if NSError != nil {
//                print("\(String(describing: NSError))")
//            }
//        })
//
//        motionManager.startGyroUpdates(to: OperationQueue.current!, withHandler: { (gyroData: CMGyroData?, NSError) -> Void in
//            if let data = gyroData?.rotationRate {
//
//                self.outputRotData(rotation: data)
//            }
//            if NSError != nil {
//                print("\(String(describing: NSError))")
//            }
//        })
        
        motionManager.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xTrueNorthZVertical , to: OperationQueue.current!, withHandler: { (motion,  error) in
            if motion != nil {
                self.trueNorth(motion: motion!)
            }
            if error != nil {
                print("\(String(describing: error))")
            }
        })
//        motionManager.deviceMotion.at
        
        motionActivityManager.startActivityUpdates(to: OperationQueue.current!) { (motion) in
            if motion?.stationary == false {
                self.is_stationary = false
            } else {
                self.is_stationary = true
            }
        }
        
        altimeter.startRelativeAltitudeUpdates(to: OperationQueue.current!) { (data, error) in
            if let relative_altitude = data?.relativeAltitude {
                let altitude = Double(truncating: relative_altitude)
                self.delegate?.sendingFloorChangeSourceData(source: .altitude, val: altitude)
                let cur_floor: Int = Int(altitude / self.altitude_floor_height)
                if cur_floor != self.altitude_floor {
                    self.delegate?.sendingFloorChange(source: .altitude, change: cur_floor - self.altitude_floor)
                    self.altitude_floor = cur_floor
                }
            }
        }
    }
    
    func reset() {
        accSys.reset()
        gyroSys.reset()
        absSys.reset()
    }
    
    // MARK: Functions
    func trueNorth(motion: CMDeviceMotion) {
        
        let acc: CMAcceleration = motion.userAcceleration
        //print(acc)
        let rot = motion.attitude.rotationMatrix
        if initial_pitch == nil {
            initial_pitch = motion.attitude.pitch
        }
        let pitch = motion.attitude.pitch - initial_pitch!
        delegate?.sendingFloorChangeSourceData(source: .rotation, val: pitch)
        if  fabs(pitch) > pitch_upperbound {
            pitch_pending_floor_change = pitch > 0 ? 1 : -1
        }
        if fabs(pitch) <  pitch_lowerbound && pitch_pending_floor_change != 0 {
            delegate?.sendingFloorChange(source: .rotation, change: pitch_pending_floor_change)
            pitch_pending_floor_change = 0
        }
        
        let x = (acc.x*rot.m11 + acc.y*rot.m21 + acc.z*rot.m31) * gravityConstant
        let y = (acc.x*rot.m12 + acc.y*rot.m22 + acc.z*rot.m32) * gravityConstant
        let z = (acc.x*rot.m13 + acc.y*rot.m23 + acc.z*rot.m33) * gravityConstant
        
//        if executePerformanceCompare == true {
//            if count <= performanceDataSize {
//                performanceDataArrayX.append(x)
//                performanceDataArrayY.append(y)
//                performanceDataArrayZ.append(z)
//                if count == performanceDataSize {
//                    //print(performanceDataArrayX)
//                    performance(arrX: performanceDataArrayX, arrY: performanceDataArrayY, arrZ: performanceDataArrayZ, performanceDataSize: performanceDataSize)
//                }
//                count += 1
//            }
//        }
        
        var test:Filter
        
        switch filterChoice {
        case .Raw:
            test = RawFilter()
        case .ThreePoint:
            test = ThreePointFilter()
        case .Kalman:
            test = KalmanFilter()
        }
        
        (absSys.accelerate.x, absSys.accelerate.y, absSys.accelerate.z) = test.filter(x: x, y: y, z: z)
        
        determineVelocityAndCoculateDistance()
        
        newData(type: speedDataType.accelerate, sensorData: absSys.accelerate)
        newData(type: speedDataType.velocity, sensorData: absSys.velocity)
        newData(type: speedDataType.distance, sensorData: absSys.distance)
        
        // Floor change from acceleration
        delegate?.sendingFloorChangeSourceData(source: .acceleration, val: absSys.velocity.z)
        
        if fabs(absSys.velocity.z) > velocity_z_upperbound {
            velocity_pending_floor_change = absSys.velocity.z > 0 ? 1 : -1
        }
        
        if fabs(absSys.velocity.z) < velocity_z_lowerbound && velocity_pending_floor_change != 0 {
            delegate?.sendingFloorChange(source: .acceleration, change: velocity_pending_floor_change)
            absSys.velocity.z = 0
            velocity_pending_floor_change = 0
        }
        
        absSys.accelerate.x = 0
        absSys.accelerate.y = 0
        absSys.accelerate.z = 0
    }
    
    func determineVelocityAndCoculateDistance() {
        if is_stationary {
            newStatus(status: "static state") // sending status to delegate
            absSys.accelerate.x = 0
            absSys.accelerate.y = 0
            absSys.accelerate.z = 0
            absSys.velocity.x = 0
            absSys.velocity.y = 0
            absSys.velocity.z = 0

        } else {
        
            newStatus(status: "dynamic state") // sending status to delegate
            if fabs(absSys.accelerate.x) > accelerationThreshold {
                absSys.velocity.x += absSys.accelerate.x * deviceMotionUpdateInterval
            }
            absSys.distance.x += absSys.velocity.x * deviceMotionUpdateInterval
            if fabs(absSys.accelerate.y) > accelerationThreshold {
                absSys.velocity.y += absSys.accelerate.y * deviceMotionUpdateInterval
            }
            absSys.distance.y += absSys.velocity.y * deviceMotionUpdateInterval
            if fabs(absSys.accelerate.z) > accelerationThreshold {
                absSys.velocity.z += absSys.accelerate.z * deviceMotionUpdateInterval
            }
            absSys.distance.z += absSys.velocity.z * deviceMotionUpdateInterval
        }
    }
    
//    func outputAccData(acceleration: CMAcceleration) {
//        // In phone's frame
//        accSys.accelerate.x = acceleration.x * gravityConstant
//        accSys.accelerate.y = acceleration.y * gravityConstant
//        accSys.accelerate.z = acceleration.z * gravityConstant
//
////        print(acceleration.x, acceleration.y, acceleration.z)
//
//        /*
//         print(modulus(accSys.accelerate.x, y: accSys.accelerate.y, z: accSys.accelerate.z) - gravityConstant, modulus(gyroSys.accelerate.x, y: gyroSys.accelerate.y, z: gyroSys.accelerate.z), modulusDiff, staticStateJudge)*/
//
//        // Static Judgement Condition 3
//        modulusDiffCalculation()
//
//        if modulusDiff != -1 && fabs(modulusDiff) < staticStateJudgeThreshold.modulusDiff {
//            staticStateJudge.modulDiffAcc = true
//        } else {
//            staticStateJudge.modulDiffAcc = false
//        }
//
//
//        // Static Judgement Condition 1
//        if fabs(modulus(x: accSys.accelerate.x, y: accSys.accelerate.y, z: accSys.accelerate.z) - gravityConstant) < staticStateJudgeThreshold.accModulus {
//            staticStateJudge.modulAcc = true
//        } else {
//            staticStateJudge.modulAcc = false
//        }
//    }
//
//    func outputRotData(rotation: CMRotationRate) {
//
//        gyroSys.accelerate.x = rotation.x
//        gyroSys.accelerate.y = rotation.y
//        gyroSys.accelerate.z = rotation.z
//
////        print(rotation.x, rotation.y,  rotation.z)
//
//        //        motionManager.devicemotion
//        if let motion = motionManager.deviceMotion {
//            let attitude = motion.attitude
//            gyroSys.rotation.pitch = attitude.pitch*180/Double.pi
//            gyroSys.rotation.roll = attitude.roll*180/Double.pi
//            gyroSys.rotation.yaw = attitude.yaw*180/Double.pi
//
//            newData(type: speedDataType.rotation, sensorData: gyroSys.rotation)
//
//            // Static Judgement Condition 2
//            if modulus(x: gyroSys.accelerate.x, y: gyroSys.accelerate.y, z: gyroSys.accelerate.z) < staticStateJudgeThreshold.gyroModulus {
//                staticStateJudge.modulGyro = true
//            } else {
//                staticStateJudge.modulGyro = false
//            }
//        }
//    }
    
    
    
//    func modulusDiffCalculation() {
//
//        if index == arrayForStatic.count {
//            accModulusAvg = 0
//            for i in 0..<(arrayForStatic.count - 1) {
//                arrayForStatic[i] = arrayForStatic[i + 1]
//                accModulusAvg += arrayForStatic[i]
//            }
//            arrayForStatic[index - 1] = modulus(x: accSys.accelerate.x, y: accSys.accelerate.y, z: accSys.accelerate.z)
//            accModulusAvg += arrayForStatic[index - 1]
//            accModulusAvg /= Double(arrayForStatic.count)
//            modulusDiff = modulusDifference(arr: arrayForStatic, avgModulus: accModulusAvg)
//        } else {
//            arrayForStatic[index] = modulus(x: accSys.accelerate.x, y: accSys.accelerate.y, z: accSys.accelerate.z)
//            index += 1
//            if index == arrayForStatic.count {
//                for element in arrayForStatic {
//                    accModulusAvg += element
//                }
//                accModulusAvg /= Double(arrayForStatic.count)
//                modulusDiff = modulusDifference(arr: arrayForStatic, avgModulus: accModulusAvg)
//            }
//        }
//    }
    
//    func performance (arrX : [Double], arrY : [Double], arrZ : [Double], performanceDataSize: Int) {
//        //let typeOfFilter = "Raw"
//        var test:Filter
//        var resultX = 0.0
//        var resultY = 0.0
//        var resultZ = 0.0
//        var outX = Array<Double>(repeating: 0, count: performanceDataSize)
//        var outY = Array<Double>(repeating: 0, count: performanceDataSize)
//        var outZ = Array<Double>(repeating: 0, count: performanceDataSize)
//
//        test = RawFilter()
//        for index in 0..<performanceDataSize {
//            (outX[index], outY[index], outZ[index]) = test.filter(x: arrX[index], y: arrY[index], z: arrZ[index])
//        }
//        resultX = standardDeviation(arr: outX)
//        resultY = standardDeviation(arr: outY)
//        resultZ = standardDeviation(arr: outZ)
//        print("Raw       :", resultX, resultY, resultZ)
//
//        test = ThreePointFilter()
//        for index in 0..<performanceDataSize {
//            (outX[index], outY[index], outZ[index]) = test.filter(x: arrX[index], y: arrY[index], z: arrZ[index])
//        }
//        resultX = standardDeviation(arr: outX)
//        resultY = standardDeviation(arr: outY)
//        resultZ = standardDeviation(arr: outZ)
//        print("ThreePoint:", resultX, resultY, resultZ)
//    }
    
}


