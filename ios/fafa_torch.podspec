#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint fafa_torch.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'fafa_torch'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for controlling the device torch.'
  s.description      = <<-DESC
A Flutter plugin for controlling the Android and iOS device flashlight,
including on/off control, brightness adjustment, and state stream events.
                       DESC
  s.homepage         = 'https://github.com/shenghaiyang/fafa_torch'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'shenghaiyang' => 'https://github.com/shenghaiyang' }
  s.source           = { :path => '.' }
  s.source_files = 'fafa_torch/Sources/fafa_torch/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
