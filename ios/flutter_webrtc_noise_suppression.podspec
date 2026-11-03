# CocoaPods build of the add-on. Not built yet: the apps it was made for take their plugins through
# Swift Package Manager (flutter_webrtc_noise_suppression/Package.swift).
Pod::Spec.new do |s|
  s.name             = 'flutter_webrtc_noise_suppression'
  s.version          = '0.0.1'
  s.summary          = 'flutter_webrtc add-on: noise suppression of the captured voice.'
  s.homepage         = 'https://github.com/SERDUN/flutter_webrtc_noise_suppression'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Dmytro Serdun'
  s.source           = { :path => '.' }
  s.source_files     = 'flutter_webrtc_noise_suppression/Sources/flutter_webrtc_noise_suppression/**/*.swift'
  s.dependency 'Flutter'
  s.dependency 'flutter_webrtc'
  s.dependency 'noise_suppression'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.resource_bundles = {
    'flutter_webrtc_noise_suppression_privacy' => ['flutter_webrtc_noise_suppression/Sources/flutter_webrtc_noise_suppression/PrivacyInfo.xcprivacy']
  }
end
