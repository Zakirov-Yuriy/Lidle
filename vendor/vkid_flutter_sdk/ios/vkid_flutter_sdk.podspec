#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint vkid_flutter_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'vkid_flutter_sdk'
  s.version          = '1.0.3'
  s.summary          = 'Flutter library for VK ID authorization'
  s.description      = 'VK ID SDK for Flutter is the most comprehensive library for user authentication via VK ID, officially supported by VK.'
  s.homepage         = 'http://example.com'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'vkid_flutter_sdk/Sources/vkid_flutter_sdk/**/*.swift'
  s.dependency 'Flutter'
  s.dependency 'VKID', "2.9.2" 
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  s.resource_bundles = {'plugin_name_privacy' => ['vkid_flutter_sdk/Sources/vkid_flutter_sdk/PrivacyInfo.xcprivacy']}
end
