#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'stt_recorder_ios'
  s.version          = '0.1.0+1'
  s.summary          = 'An iOS implementation of the stt_recorder plugin.'
  s.description      = <<-DESC
  An iOS implementation of the stt_recorder plugin.
                       DESC
  s.homepage         = 'https://github.com/MahMoos/stt_recorder'
  s.license          = { :type => 'BSD', :file => '../LICENSE' }
  s.author           = { 'MahMoos' => 'mahmoos313@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'stt_recorder_ios/Sources/**/*.swift'
  s.dependency 'Flutter'
  s.frameworks = 'Speech', 'AVFoundation'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '6.1'
end
