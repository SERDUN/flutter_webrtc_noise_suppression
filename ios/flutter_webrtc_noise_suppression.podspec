# CocoaPods build of the add-on; Swift Package Manager builds it from
# flutter_webrtc_noise_suppression/Package.swift.
Pod::Spec.new do |s|
  s.name             = 'flutter_webrtc_noise_suppression'
  s.version          = '0.0.1'
  s.summary          = 'flutter_webrtc add-on: noise suppression (RNNoise) of the captured voice.'
  s.homepage         = 'https://github.com/SERDUN/flutter_webrtc_noise_suppression'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Dmytro Serdun'
  s.source           = { :path => '.' }
  s.source_files     = 'flutter_webrtc_noise_suppression/Sources/**/*.{h,m,c,swift}'
  s.public_header_files = [
    'flutter_webrtc_noise_suppression/Sources/NoiseSuppression/include/NoiseSuppression/*.h',
    'flutter_webrtc_noise_suppression/Sources/NoiseSuppressionCore/include/*.h',
  ]
  s.dependency 'Flutter'
  s.dependency 'flutter_webrtc'
  # flutter_webrtc is a static framework: a dynamic pod over it is refused by `pod install`.
  s.static_framework = true
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/flutter_webrtc_noise_suppression/Sources/NoiseSuppressionCore/include" "${PODS_TARGET_SRCROOT}/flutter_webrtc_noise_suppression/Sources/NoiseSuppressionCore/rnnoise/include"',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'common=ns_rnnoise_common',
    'WARNING_CFLAGS' => '-w',
  }
  s.resource_bundles = {
    'flutter_webrtc_noise_suppression_privacy' => ['flutter_webrtc_noise_suppression/Sources/flutter_webrtc_noise_suppression/PrivacyInfo.xcprivacy']
  }
end
