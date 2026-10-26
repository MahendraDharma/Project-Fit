# The ProjectFit side of the Garmin watch bridge (garmin-bridge/), on Garmin's
# Connect IQ Mobile SDK. The SDK binary is not in this repository: the Podfile
# fetches it from github.com/garmin/connectiq-companion-app-sdk-ios at a fixed
# commit into Vendor/ before `pod install` reads this file.
Pod::Spec.new do |s|
  s.name             = 'ProjectFitConnectIQ'
  s.version          = '1.0.0'
  s.summary          = 'ProjectFit <-> Connect IQ watch app bridge.'
  s.homepage         = 'https://github.com/MahendraDharma/Project-Fit'
  s.license          = { :type => 'Proprietary', :text => 'ProjectFit' }
  s.author           = 'ProjectFit'
  s.source           = { :path => '.' }
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'
  s.source_files     = 'Classes/**/*.swift'
  s.vendored_frameworks = 'Vendor/ConnectIQ.xcframework'
  s.dependency 'Flutter'
  # The SDK uses Objective-C categories internally (its own setup notes).
  s.pod_target_xcconfig  = { 'OTHER_LDFLAGS' => '$(inherited) -ObjC' }
  s.user_target_xcconfig = { 'OTHER_LDFLAGS' => '$(inherited) -ObjC' }
end
