//
//  PLayerView.swift
//  Gbox
//
//  Created by Guillermo Anaya on 9/17/15.
//  Copyright © 2015 Gbox. All rights reserved.
//

import UIKit
import AVFoundation

final public class PLayerView: UIView {

  override public class func layerClass() -> AnyClass {
    return AVPlayerLayer.self
  }
  
  var player: AVPlayer {
    get {
      let playerLayer = layer as! AVPlayerLayer
      if playerLayer.player == nil {
        playerLayer.player = AVPlayer()
        playerLayer.player?.allowsExternalPlayback = true
      }
      return playerLayer.player!
    }
    
    set(player) {
      (self.layer as! AVPlayerLayer).player = player
    }
    
  }
  
  var fillMode: String! {
    get {
      return (self.layer as! AVPlayerLayer).videoGravity
    }
    set {
      (self.layer as! AVPlayerLayer).videoGravity = newValue
    }
  }
  
  var playerLayer: AVPlayerLayer! {
    get {
      return self.layer as! AVPlayerLayer
    }
  }
  
  override public func layoutSubviews() {
    super.layoutSubviews()
  }

}
