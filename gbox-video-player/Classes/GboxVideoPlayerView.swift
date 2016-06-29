//
//  GboxVideoPlayerView.swift
//  Gbox
//
//  Created by Guillermo Anaya on 9/16/15.
//  Copyright © 2015 Gbox. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMedia

var ItemStatusContext = "ItemStatusContext"

public enum PlaybackState: Int, CustomStringConvertible {
  case Stopped = 0
  case Playing
  case Paused
  case Failed
  
  public var description: String {
    get {
      switch self {
      case Stopped:
        return "Stopped"
      case Playing:
        return "Playing"
      case Failed:
        return "Failed"
      case Paused:
        return "Paused"
      }
    }
  }
}

public enum BufferingState: Int, CustomStringConvertible {
  case Unknown = 0
  case Ready
  case Delayed
  
  public var description: String {
    get {
      switch self {
      case Unknown:
        return "Unknown"
      case Ready:
        return "Ready"
      case Delayed:
        return "Delayed"
      }
    }
  }
}

// KVO contexts

private var PlayerObserverContext = 0
private var PlayerItemObserverContext = 0
private var PlayerLayerObserverContext = 0

// KVO player keys

private let PlayerTracksKey = "tracks"
private let PlayerPlayableKey = "playable"
private let PlayerDurationKey = "duration"
private let PlayerRateKey = "rate"

// KVO player item keys

private let PlayerStatusKey = "status"
private let PlayerEmptyBufferKey = "playbackBufferEmpty"
private let PlayerKeepUp = "playbackLikelyToKeepUp"

// KVO player layer keys

private let PlayerReadyForDisplay = "readyForDisplay"

let kVideoDelayControls: Double = 3.5
let kVideoControlAnimationTimeinterval: NSTimeInterval  = 0.3
let kVideoControlBarAutoFadeOutTimeinterval: NSTimeInterval = 5.0

public protocol PlayerDelegate: class {
  func playerReady(player: GboxVideoPlayerView)
  func playerPlaybackStateDidChange(player: GboxVideoPlayerView)
  func playerBufferingStateDidChange(player: GboxVideoPlayerView)
  
  func playerPlaybackWillStartFromBeginning(player: GboxVideoPlayerView)
  func playerPlaybackDidEnd(player: GboxVideoPlayerView)
  func toggleFullscreen()
}

public protocol Tappable {
  func addTap(selector: Selector)
}

extension Tappable where Self: UIView, Self: UIGestureRecognizerDelegate{
  public func addTap(selector: Selector) {
    let tapGesture = UITapGestureRecognizer(target: self, action: selector)
    tapGesture.delegate = self
    self.addGestureRecognizer(tapGesture)
  }
}

//MARK: View

public class GboxVideoPlayerView: UIView, UIGestureRecognizerDelegate {

  @IBOutlet weak var playerView: PLayerView!
  @IBOutlet weak var loading: UIActivityIndicatorView!
  @IBOutlet weak var scrubber: GboxSlider!
  @IBOutlet weak var playPauseButton: UIButton!
  
  @IBOutlet weak var totalTimeLbl: UILabel!
  @IBOutlet weak var currentTimeLbl: UILabel!
  @IBOutlet weak public var fullscreenButton: UIButton!
  
  @IBOutlet weak public var backgroundErrorImage: UIImageView!
  @IBOutlet weak public var errorVideoState: UIView!
  @IBOutlet weak public var overlay: UIView!
  @IBOutlet weak public var shareButton: UIButton!
  @IBOutlet weak public var chromeCastButton: UIButton!
  @IBOutlet weak public var backButton: UIButton!
  @IBOutlet weak public var overlayImage: UIImageView!
  
  @IBOutlet weak public var bufferBackButton: UIButton!
  public weak var delegate: PlayerDelegate?
  private var visibleInterfaceOrientation: UIInterfaceOrientation = .Portrait
  
  let kTracksKey = "tracks"
  let kPlayableKey = "playable"
  
  private var playerItem: AVPlayerItem?
  private var player: AVPlayer!
  
  private var videoStartFromSecond: Float64 = 0
  
  public var track: Tackable {
    get {
      return self.track
    }
    
    set(newValue) {
      if(self.playbackState == .Playing){
        self.pause()
      }
      
      //videoTitle.text = newValue.title
      self.setupPlayerItem(nil)
      let asset = AVURLAsset(URL: newValue.streamURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
      self.setupAsset(asset)
    }
  }
  
  public func muted(value: Bool) {
    player?.muted = value
  }
  
  private var scrubbing = false
  private var isBarShowing = true
  
  func animateHide() {
    if !isBarShowing {
      return
    }
    
    UIView.animateWithDuration(kVideoControlAnimationTimeinterval, animations: { _ in
      let _ = [self.overlay, self.scrubber, self.playPauseButton, self.totalTimeLbl, self.currentTimeLbl, self.fullscreenButton].map { $0.alpha = 0 }
      }) { success in
        
        self.isBarShowing = false
    }
  }
  
  func animateShow() {
    if isBarShowing {
      return
    }
    UIView.animateWithDuration(kVideoControlAnimationTimeinterval, animations: { _ in
      let _ = [self.overlay, self.scrubber, self.playPauseButton, self.totalTimeLbl, self.currentTimeLbl, self.fullscreenButton].map { $0.alpha = 1 }
      }) { success in
        self.isBarShowing = true
        self.autoFadeOutControlBar()
    }
  }
  
  func autoFadeOutControlBar() {
    if !isBarShowing {
      return
    }
    cancelAutoFadeOutControlBar()
    self.performSelector(#selector(GboxVideoPlayerView.animateHide), withObject: nil, afterDelay: kVideoControlBarAutoFadeOutTimeinterval)
  }
  
  func cancelAutoFadeOutControlBar() {
    NSObject.cancelPreviousPerformRequestsWithTarget(self, selector: #selector(GboxVideoPlayerView.animateHide), object: nil)
  }
  
  public var isHideControls: Bool {
    get {
      return [scrubber, playPauseButton, totalTimeLbl, currentTimeLbl, fullscreenButton].map { $0.alpha == 0 }.reduce(true, combine: { $0 && $1 })
    }
  }
  
  private var asset: AVAsset!
  
  public var playbackState: PlaybackState = .Stopped {
    
    willSet (newValue){
      if newValue == self.playbackState {
        return
      }
      dispatch_async(dispatch_get_main_queue(), { () -> Void in
        self.playbackState = newValue
        switch self.playbackState {
        case .Paused:
          self.player.pause()
          let image = UIImage(named: "icPlay.png", inBundle: NSBundle(forClass: GboxSlider.self), compatibleWithTraitCollection: nil)
          self.playPauseButton.setImage(image, forState: .Normal)
        case .Failed:
          self.loading.stopAnimating()
          self.loading.hidden = true
          self.errorVideoState.hidden = false
          self.errorVideoState.addSubview(self.bufferBackButton) //bringSubviewToFront(self.bufferBackButton)
          self.player.pause()
          let image = UIImage(named: "icPlay.png", inBundle: NSBundle(forClass: GboxSlider.self), compatibleWithTraitCollection: nil)
          self.playPauseButton.setImage(image, forState: .Normal)
        case .Playing:
          self.player.play()
          let image = UIImage(named: "icPause.png", inBundle: NSBundle(forClass: GboxSlider.self), compatibleWithTraitCollection: nil)
          self.playPauseButton.setImage(image, forState: .Normal)
        case .Stopped:
          self.player.pause()
          let image = UIImage(named: "icPlay.png", inBundle: NSBundle(forClass: GboxSlider.self), compatibleWithTraitCollection: nil)
          self.playPauseButton.setImage(image, forState: .Normal)
        }
      })
    }
  }
  
  
  public var bufferingState: BufferingState = .Unknown {
    willSet(newValue) {
      if newValue == self.bufferingState {
        return
      }
      
      //dispatch_async(dispatch_get_main_queue(), { () -> Void in
        self.bufferingState = newValue
        switch self.bufferingState {
        case .Delayed, .Unknown:
          self.loading.startAnimating()
          self.loading.hidden = false
        case .Ready:
          self.loading.stopAnimating()
          self.loading.hidden = true
          
        }
      //})
    }
  }
  
  public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
    if touch.view is GboxSlider || touch.view is UIButton{
      return false
    }
    return true
  }
  
  private var _timeObserver:AnyObject?
  
  private var fullscreenToggle = false
  
  public var playbackFreezesAtEnd: Bool!
  public var currentSecondPlayed: Float64 = 0
  
  public var muted: Bool! {
    get {
      return self.playerView.player.muted
    }
    set {
      self.playerView.player.muted = newValue
    }
  }
  
  
  public var fillMode: String! {
    get {
      return self.playerView.fillMode
    }
    set {
      self.playerView.fillMode = newValue
    }
  }
  
  public var playbackLoops: Bool! {
    get {
      return (self.player.actionAtItemEnd == .None) as Bool
    }
    set {
      if newValue.boolValue {
        self.player.actionAtItemEnd = .None
      } else {
        self.player.actionAtItemEnd = .Pause
      }
    }
  }
  
  public override func awakeFromNib() {
    super.awakeFromNib()
  }
  
  override public init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setup()
  }
  
  func tapOverVideo(sender: UITapGestureRecognizer) {
    if sender.state == .Recognized {
      if isBarShowing {
        self.animateHide()
      } else {
        self.animateShow()
      }
    }
  }
  
  let airPlayHelper = AirPlayHelper()
  
  public func setup() {
    let nib = NSBundle(forClass: GboxVideoPlayerView.self).loadNibNamed("GboxVideoPlayerView", owner: self, options: nil).first as! UIView
    nib.frame = self.bounds
    self.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
    self.addSubview(nib)
    self.playerView.fillMode = AVLayerVideoGravityResizeAspect
    self.playerView.playerLayer.hidden = true
    do {
      try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print(error)
    }
    
    
    let wrapperView = airPlayHelper.airPlayButton()
    overlay.addSubview(wrapperView)
    
    wrapperView.topAnchor.constraintEqualToAnchor(chromeCastButton.topAnchor, constant: 4).active = true
    wrapperView.widthAnchor.constraintEqualToAnchor(nil, constant: 40).active = true
    wrapperView.heightAnchor.constraintEqualToAnchor(nil, constant: 40).active = true
    wrapperView.trailingAnchor.constraintEqualToAnchor(chromeCastButton.trailingAnchor, constant: -50).active = true
    
    
    airplayConnected(airPlayHelper.isAlredyConnected())
    airPlayHelper.delegate = self
    
    self.addTap(#selector(GboxVideoPlayerView.tapOverVideo(_:)))
    
    self.player = AVPlayer()
    self.player.actionAtItemEnd = .Pause
    self.player.addObserver(self, forKeyPath: PlayerRateKey, options: ([NSKeyValueObservingOptions.New, NSKeyValueObservingOptions.Old]) , context: &PlayerObserverContext)
    
    self.playbackState = .Stopped
    self.bufferingState = .Unknown
    
    self.playerView.layer.addObserver(self, forKeyPath: PlayerReadyForDisplay, options: ([NSKeyValueObservingOptions.New, NSKeyValueObservingOptions.Old]), context: &PlayerLayerObserverContext)
    
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(UIApplicationDelegate.applicationWillResignActive(_:)), name: UIApplicationWillResignActiveNotification, object: UIApplication.sharedApplication())
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(UIApplicationDelegate.applicationDidEnterBackground(_:)), name: UIApplicationDidEnterBackgroundNotification, object: UIApplication.sharedApplication())
    
    //check deinit
    self.scrubber.delegate = self
    playbackFreezesAtEnd = true
    loading.startAnimating()
    player.addObserver(self, forKeyPath: PlayerDurationKey, options: NSKeyValueObservingOptions.New, context: nil)
    startObservers()
  }
  
  public func seekToTimeInSecond(seconds: CMTime, completion: (Bool) -> ()) {
    self.player.seekToTime(seconds, completionHandler: completion)
  }
  
  public func seekToTimeCurrentPlayedSeconds(completion: (Bool) -> ()) {
    self.player.seekToTimeInSeconds(currentSecondPlayed, completion: completion)
  }
  
  public func seekToTime(time: CMTime) {
    if let playerItem = self.playerItem {
      return playerItem.seekToTime(time)
    }
  }
  
  func startObservers() {
    if (_timeObserver == nil) {
      _timeObserver = player.addPeriodicTimeObserverForInterval(CMTimeMake(1, 100), queue: dispatch_get_main_queue(),
        usingBlock: { [weak self] (time: CMTime) -> Void in
          let seconds:Float64 = CMTimeGetSeconds(time)
          if (!isnan(seconds) && !isinf(seconds)) {
            self?.positionUpdated(seconds)
          }
      })
    }
  }
  
  func stopObservers() {
    if (_timeObserver != nil) {
      player?.removeTimeObserver(_timeObserver!)
      _timeObserver = nil
    }
  }
  
  public func positionUpdated(seconds: Float64) {
    currentSecondPlayed = seconds
    self.currentTimeLbl.text = seconds.minutes
    self.scrubber.value = Float(seconds / CMTimeGetSeconds(player.currentItem!.duration))
  }
  
  deinit {
    print(#function)
    
    player.removeObserver(self, forKeyPath: PlayerRateKey)
    player.removeObserver(self, forKeyPath: PlayerDurationKey)
    playerView?.layer.removeObserver(self, forKeyPath: PlayerReadyForDisplay)
    NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationWillResignActiveNotification, object: UIApplication.sharedApplication())
    NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationDidEnterBackgroundNotification, object: UIApplication.sharedApplication())
    self.player.pause()
    self.setupPlayerItem(nil)
    stopObservers()
    self.delegate = nil
  }
  
  private func setupAsset(asset: AVAsset) {
    if playbackState == .Playing {
      pause()
    }
    
    bufferingState = .Unknown
    delegate?.playerBufferingStateDidChange(self)
    
    self.asset = asset
    if let _ = self.asset {
      setupPlayerItem(nil)
    }
    
    let keys: [String] = [PlayerTracksKey, PlayerPlayableKey, PlayerDurationKey]
    
    self.asset.loadValuesAsynchronouslyForKeys(keys, completionHandler: { () -> Void in
      dispatch_sync(dispatch_get_main_queue(), { [weak self] () -> Void in
        if let strongSelf = self {
          for key in keys {
            var error: NSError?
            let status = strongSelf.asset.statusOfValueForKey(key, error:&error)
            if status == .Failed {
              strongSelf.playbackState = .Failed
              strongSelf.delegate?.playerPlaybackStateDidChange(strongSelf)
              print(error)
              return
            }
          }
          
          if strongSelf.asset.playable.boolValue == false {
            strongSelf.playbackState = .Failed
            strongSelf.delegate?.playerPlaybackStateDidChange(strongSelf)
            return
          }
          
          let playerItem: AVPlayerItem = AVPlayerItem(asset:strongSelf.asset)
          strongSelf.totalTimeLbl.text = CMTimeGetSeconds(playerItem.duration).minutes
          strongSelf.setupPlayerItem(playerItem)
        }
      })
    })
  }
  
  private func setupPlayerItem(playerItem: AVPlayerItem?) {
    if self.playerItem != nil {
      self.playerItem?.removeObserver(self, forKeyPath: PlayerEmptyBufferKey, context: &PlayerItemObserverContext)
      self.playerItem?.removeObserver(self, forKeyPath: PlayerKeepUp, context: &PlayerItemObserverContext)
      self.playerItem?.removeObserver(self, forKeyPath: PlayerStatusKey, context: &PlayerItemObserverContext)
      
      NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemDidPlayToEndTimeNotification, object: self.playerItem)
      NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemFailedToPlayToEndTimeNotification, object: self.playerItem)
    }
    
    self.playerItem = playerItem
    
    if self.playerItem != nil {
      self.playerItem?.addObserver(self, forKeyPath: PlayerEmptyBufferKey, options: ([NSKeyValueObservingOptions.New, NSKeyValueObservingOptions.Old]), context: &PlayerItemObserverContext)
      self.playerItem?.addObserver(self, forKeyPath: PlayerKeepUp, options: ([NSKeyValueObservingOptions.New, NSKeyValueObservingOptions.Old]), context: &PlayerItemObserverContext)
      self.playerItem?.addObserver(self, forKeyPath: PlayerStatusKey, options: ([NSKeyValueObservingOptions.New, NSKeyValueObservingOptions.Old]), context: &PlayerItemObserverContext)
      
      NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(GboxVideoPlayerView.playerItemDidPlayToEndTime(_:)), name: AVPlayerItemDidPlayToEndTimeNotification, object: self.playerItem)
      NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(GboxVideoPlayerView.playerItemFailedToPlayToEndTime(_:)), name: AVPlayerItemFailedToPlayToEndTimeNotification, object: self.playerItem)
    }
    
    self.player.replaceCurrentItemWithPlayerItem(self.playerItem)
    
    if self.playbackLoops.boolValue == true {
      self.player.actionAtItemEnd = .None
    } else {
      self.player.actionAtItemEnd = .Pause
    }
  }
  
  @IBAction func tapPause(sender: UIButton) {
    if self.playbackState == .Playing {
      self.pause()
    } else {
      self.playFromCurrentTime()
    }
  }
  
  @IBAction func tapFullScreen(sender: UIButton) {
    
  }
  
  
  // MARK: NSNotifications
  
  public func playerItemDidPlayToEndTime(aNotification: NSNotification) {
    if self.playbackLoops.boolValue == true || self.playbackFreezesAtEnd.boolValue == true {
      self.player.seekToTime(kCMTimeZero)
    }
    videoStartFromSecond = 0
    currentSecondPlayed = 0
    if self.playbackLoops.boolValue == false {
      self.stop()
    }
  }
  
  public func playerItemFailedToPlayToEndTime(aNotification: NSNotification) {
    print(aNotification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey])
    self.playbackState = .Failed
    self.delegate?.playerPlaybackStateDidChange(self)
    
    NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemDidPlayToEndTimeNotification, object: self.playerItem)
    NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemFailedToPlayToEndTimeNotification, object: self.playerItem)
  }
  
  public func applicationWillResignActive(aNotification: NSNotification) {
    if self.playbackState == .Playing {
      self.pause()
    }
  }
  
  public func applicationDidEnterBackground(aNotification: NSNotification) {
    if self.playbackState == .Playing {
      self.pause()
    }
  }
  
  //MARK: Rotation
  
  
  // MARK: KVO
  override public func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
    
    switch (keyPath, context) {
    case (.Some(PlayerRateKey), &PlayerObserverContext):
      true
    case (.Some(PlayerStatusKey), &PlayerItemObserverContext):
      true
    case (.Some(PlayerKeepUp), &PlayerItemObserverContext):
      if let item = self.playerItem {
        self.bufferingState = .Ready
        self.delegate?.playerBufferingStateDidChange(self)
        self.autoFadeOutControlBar()
        if item.playbackLikelyToKeepUp && self.playbackState == .Playing {
          self.playFromCurrentTime()
        }
      }
      
      let status = (change?[NSKeyValueChangeNewKey] as! NSNumber).integerValue as AVPlayerStatus.RawValue
      
      switch (status) {
      case AVPlayerStatus.ReadyToPlay.rawValue:
        self.playerView.playerLayer.player = self.player
        self.playerView.playerLayer.hidden = false
        if videoStartFromSecond > 0 {
          player.seekToTimeInSeconds(videoStartFromSecond) { [weak self] success in
            if success {
              self?.playbackState = .Playing
              self?.videoStartFromSecond = 0
            }
          }
        }
      case AVPlayerStatus.Failed.rawValue:
        self.playbackState = PlaybackState.Failed
        self.delegate?.playerPlaybackStateDidChange(self)
      default:
        true
      }
    case (.Some(PlayerEmptyBufferKey), &PlayerItemObserverContext):
      if let item = self.playerItem {
        if item.playbackBufferEmpty {
          self.bufferingState = .Delayed
          self.delegate?.playerBufferingStateDidChange(self)
        }
      }
      
      let status = (change?[NSKeyValueChangeNewKey] as! NSNumber).integerValue as AVPlayerStatus.RawValue
      
      switch (status) {
      case AVPlayerStatus.ReadyToPlay.rawValue:
        self.playerView.playerLayer.player = self.player
        self.playerView.playerLayer.hidden = false
      case AVPlayerStatus.Failed.rawValue:
        self.playbackState = PlaybackState.Failed
        self.delegate?.playerPlaybackStateDidChange(self)
      default:
        true
      }
    case (.Some(PlayerReadyForDisplay), &PlayerLayerObserverContext):
      if self.playerView.playerLayer.readyForDisplay {
        self.delegate?.playerReady(self)
      }
    default:
      super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
      
    }
  }
  
}

//MARK: Actions
extension GboxVideoPlayerView {
  public func pause() {
    if self.playbackState != .Playing {
      return
    }
    
    self.playbackState = .Paused
    self.delegate?.playerPlaybackStateDidChange(self)
  }
  
  public func stop() {
    if self.playbackState == .Stopped {
      return
    }
    
    self.playbackState = .Stopped
    self.delegate?.playerPlaybackStateDidChange(self)
    self.delegate?.playerPlaybackDidEnd(self)
  }
  
  public func playFromBeginning() {
    self.delegate?.playerPlaybackWillStartFromBeginning(self)
    self.player.seekToTime(kCMTimeZero)
    videoStartFromSecond = 0
    self.currentTimeLbl.text = "00:00"
    self.playFromCurrentTime()
  }
  
  public func playFromCurrentTime() {
    self.playbackState = .Playing
    self.delegate?.playerPlaybackStateDidChange(self)
  }
  
  public func playFromSeconds(seconds: Float64) {
    self.videoStartFromSecond = seconds
  }
  
  public func stopPositionUpdater() {
    stopObservers()
  }
  
  public func startPositionUpdater() {
    startObservers()
  }
  
}

extension GboxVideoPlayerView: SliderActions {
  func slideEnd() {
    scrubbing = false
    let seconds = Float64(scrubber.value)
    let timeafterSeek = Float64(seconds * CMTimeGetSeconds(player.currentItem!.duration))
    self.player.seekToTimeInSeconds(timeafterSeek) { [weak self] success in
      if success {
        self?.currentSecondPlayed = timeafterSeek
        self?.currentTimeLbl.text = timeafterSeek.minutes
        self?.playFromCurrentTime()
        self?.autoFadeOutControlBar()
      }
    }
  }
  
  func slideBeggin() {
    scrubbing = true
    self.pause()
    cancelAutoFadeOutControlBar()
    videoStartFromSecond = 0
  }
  
  func dragging(sender: AnyObject) {
    guard let slider = sender as? UISlider else { return }
    let seconds = Float64(slider.value)
    let timeafterSeek = Float64(seconds * CMTimeGetSeconds(self.player.currentItem!.duration))
    currentTimeLbl.text = timeafterSeek.minutes
  }
}

extension GboxVideoPlayerView: Tappable { }


extension AVPlayer {
  func seekToTimeInSeconds(seconds: Float64, completion: (Bool) -> ()) {
    if self.respondsToSelector(#selector(AVPlayer.seekToTime(_:toleranceBefore:toleranceAfter:completionHandler:))) {
      self.seekToTime(CMTimeMakeWithSeconds(seconds, self.currentItem!.duration.timescale),
        toleranceBefore: kCMTimeZero,
        toleranceAfter: kCMTimeZero,
        completionHandler: completion)
    } else {
      self.seekToTime(CMTimeMakeWithSeconds(seconds, 1),
        toleranceBefore: kCMTimeZero,
        toleranceAfter: kCMTimeZero)
      completion(true)
    }
  }
}

extension Float64 {
  var minutes: String {
    return "\(String(format: "%02d", Int(self / 60))):\(String(format: "%02d", Int(self % 60)))"
  }
}

extension GboxVideoPlayerView: AirPlayDelegate {
  func airplayConnected(isConnected: Bool) {
    overlayImage.hidden = !isConnected
  }
}
