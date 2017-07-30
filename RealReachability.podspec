#
#  Be sure to run `pod spec lint RealReachability.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#
Pod::Spec.new do |s|
  s.name         = "RealReachability"
  s.version      = "1.1.9"
  s.summary      = "We need to observe the REAL reachability of network for iOS. That's what RealReachability do."


  # Add desc next time.
  s.homepage     = "https://github.com/dustturtle/RealReachability"
  # Add screenshots next time.
  s.license      = "MIT"
  s.author             = { "GuanZhenwei" => "openglnewbee@163.com" }
  s.platform = :ios
  s.ios.deployment_target = '7.0'
  s.source  = { :git => "https://github.com/dustturtle/RealReachability.git", :tag => s.version, :submodules => true }
  s.source_files  = "RealReachability", "RealReachability/FSM"
  s.requires_arc = true

  s.public_header_files = 'RealReachability/RealReachability.h'

  s.subspec 'Connection' do |ss|
    ss.source_files = "RealReachability/Connection"
    ss.public_header_files = 'RealReachability/Connection/LocalConnection.h'
  end

  s.subspec 'Ping' do |ss|
    ss.source_files = "RealReachability/Ping"
    ss.public_header_files = 'RealReachability/Ping/PingHelper.h'
  end
end
