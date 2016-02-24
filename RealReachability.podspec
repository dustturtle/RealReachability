#
#  Be sure to run `pod spec lint RealReachability.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#
Pod::Spec.new do |s|
  s.name         = "RealReachability"
  s.version      = "1.1.1"
  s.summary      = "We need to observe the REAL reachability of network for iOS. That's what RealReachability do."


  # Add desc next time.
  s.homepage     = "https://github.com/dustturtle/RealReachability"
  # Add screenshots next time.
  s.license      = "MIT"
  s.author             = { "GuanZhenwei" => "openglnewbee@163.com" }
  s.platform = :ios
  s.ios.deployment_target = '6.0'
  s.source       = { :git => "https://github.com/dustturtle/RealReachability.git", :tag => "1.1.1" }
  s.source_files  = "RealReachability", "RealReachability/FSM", "RealReachability/Connection", "RealReachability/Ping"
  s.requires_arc = true
end
