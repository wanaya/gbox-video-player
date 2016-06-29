//
//  AirPlayHelper.swift
//  Gbox
//
//  Created by Guillermo Anaya on 6/13/16.
//  Copyright © 2016 Gbox. All rights reserved.
//

import UIKit
import MediaPlayer

protocol AirPlayDelegate: class {
  func airplayConnected(isConnected: Bool)
}

final class AirPlayHelper: NSObject {
  
  weak var delegate: AirPlayDelegate? = nil
  
  override init() {
    super.init()
    NSNotificationCenter.defaultCenter().addObserver(
      self,
      selector: #selector(AirPlayHelper.airplayChanged(_:)),
      name: AVAudioSessionRouteChangeNotification,
      object: AVAudioSession.sharedInstance())
  }
  
  func airplayChanged(sender: NSNotification) {
    let currentRoute = AVAudioSession.sharedInstance().currentRoute
    var isAirPlayPlaying = false
    for output in currentRoute.outputs {
      if output.portType == AVAudioSessionPortAirPlay {
        print("Airplay Device connected with name: \(output.portName)")
        isAirPlayPlaying = true
        break;
      }
    }
    
    delegate?.airplayConnected(isAirPlayPlaying)
  }
  
  func isAlredyConnected() -> Bool {
    let currentRoute = AVAudioSession.sharedInstance().currentRoute
    for output in currentRoute.outputs {
      if output.portType == AVAudioSessionPortAirPlay {
        print("Airplay Device connected with name: \(output.portName)")
        return true
      }
    }
    
    return false
  }
  
  func airPlayButton() -> UIView {
    let wrapperView = UIView(frame: CGRectMake(0, 0, 40, 40))
    wrapperView.backgroundColor = UIColor.clearColor()
    wrapperView.translatesAutoresizingMaskIntoConstraints = false
    
    let volumneView = MPVolumeView(frame: wrapperView.bounds)
    volumneView.showsVolumeSlider = false
    wrapperView.addSubview(volumneView)
    
    volumneView.sizeToFit()
    return wrapperView
  }
  
  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(
      self,
      name: AVAudioSessionRouteChangeNotification,
      object: AVAudioSession.sharedInstance())
    print("deinit AirPlayHelper")
  }
}
