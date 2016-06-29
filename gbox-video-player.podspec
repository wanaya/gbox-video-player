#
# Be sure to run `pod lib lint gbox-video-player.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'gbox-video-player'
  s.version          = '0.1.0'
  s.summary          = 'A video player createdin swift'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = 'a simple video player that accept video and mp3'

  s.homepage         = 'https://github.com/wanaya/gbox-video-player'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'guillermoncircle' => 'guillermo@oncircle.com' }
  s.source           = { :git => 'https://github.com/wanaya/gbox-video-player.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/wanaya'

  s.ios.deployment_target = '9.0'

  s.source_files = 'gbox-video-player/Classes/**/*'
  
  s.resource_bundles = {
    'gbox-video-player' => ['gbox-video-player/Assets/*.{xib,png}']
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
