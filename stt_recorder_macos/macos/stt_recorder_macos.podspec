Pod::Spec.new do |s|
  s.name             = 'stt_recorder_macos'
  s.version          = '0.1.0+1'
  s.summary          = 'A macOS implementation of the stt_recorder plugin.'
  s.description      = <<-DESC
A macOS implementation of the stt_recorder plugin.
                       DESC
  s.homepage         = 'https://github.com/MahMoos/stt_recorder'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'MahMoos' => 'mahmoos313@gmail.com' }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'

  s.dependency 'FlutterMacOS'
  s.frameworks = 'AVFoundation', 'Speech', 'AVKit'

  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
