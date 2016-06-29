//
//  ViewController.swift
//  gbox-video-player
//
//  Created by guillermoncircle on 06/28/2016.
//  Copyright (c) 2016 guillermoncircle. All rights reserved.
//

import UIKit
import gbox_video_player

class ViewController: UIViewController {

  @IBOutlet weak var heightCons: NSLayoutConstraint!
  @IBOutlet weak var videoPlayer: GboxVideoPlayerView!
  let deafultHeight: CGFloat = 212
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    
    let track = GboxTrack(url: NSURL(string: "https://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!, title: "Bunny")
    videoPlayer?.track = track
    videoPlayer?.playFromBeginning()
    
    videoPlayer?.fullscreenButton.addTarget(self, action: #selector(ViewController.tapFullScreen), forControlEvents: .TouchUpInside)
  }
  
  func tapFullScreen() {
    fullScreen = !fullScreen
  }
  
  var fullScreen: Bool! {
    get {
      return UIDeviceOrientationIsLandscape(UIDevice.currentDevice().orientation)
    }
    
    set {
      if let value = newValue where value {
        UIDevice.currentDevice().setValue(UIInterfaceOrientation.LandscapeRight.rawValue, forKey: "orientation")
      } else {
        UIDevice.currentDevice().setValue(UIInterfaceOrientation.Portrait.rawValue, forKey: "orientation")
      }
    }
  }
  
  override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
    let isLandscape = UIInterfaceOrientationIsLandscape(toInterfaceOrientation)
    self.navigationController?.setNavigationBarHidden(isLandscape, animated: true)
    videoPlayer.backButton.hidden = isLandscape
    videoPlayer.bufferBackButton.hidden = isLandscape
    self.prefersStatusBarHidden()
    let bounds = UIScreen.mainScreen().bounds
    
    if UIInterfaceOrientationIsLandscape(toInterfaceOrientation) {
      self.heightCons.constant = min(bounds.size.width, bounds.size.height)
    } else {
      self.heightCons.constant = deafultHeight
      self.navigationController?.navigationBarHidden = true
    }
    
    UIView.animateWithDuration(0.5, delay: 0.0, options: [], animations: { () -> Void in
      self.view.layoutIfNeeded()
      }, completion: nil)
  }
}

