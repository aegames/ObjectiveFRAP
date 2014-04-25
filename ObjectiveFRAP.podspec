#
# Be sure to run `pod spec lint ObjectiveFRAP.podspec' to ensure this is a
# valid spec.
#
# Remove all comments before submitting the spec. Optional attributes are commented.
#
# For details see: https://github.com/CocoaPods/CocoaPods/wiki/The-podspec-format
#
Pod::Spec.new do |s|
  s.name         = "ObjectiveFRAP"
  s.version      = "0.0.1"
  s.license      = "MIT"
  s.summary      = "An Objective-C implementation of a FRAP protocol endpoint."
  s.description  = <<-DESC
                   FRAP is a protocol for multiplayer networked games.  It was created for Fire on High.  ObjectiveFRAP is an implementation of FRAP in Objective-C,
                   which is compatible with iOS and Mac OS X.
                   DESC
  s.homepage     = "https://github.com/aegames/ObjectiveFRAP"
  s.author       = { "Nat Budin" => "natbudin@gmail.com", :tag => "v0.0.1" }

  s.source       = { :git => "https://github.com/aegames/ObjectiveFRAP.git" }

  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.6'

  s.source_files = 'ObjectiveFRAP', 'ObjectiveFRAP/**/*.{h,m}'
  s.public_header_files = 'ObjectiveFRAP/*.h'
  s.requires_arc = true

  s.dependency 'CocoaAsyncSocket'
  s.dependency 'Reachability'
  s.dependency 'hiredis'
end
