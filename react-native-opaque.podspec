require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

rustlib_xcconfig = {

  # add rust lib release targets
  'LIBRARY_SEARCH_PATHS[sdk=iphoneos*][arch=arm64]' => '${PODS_TARGET_SRCROOT}/rust/target/aarch64-apple-ios/release',
  'LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*][arch=x86_64]' => '${PODS_TARGET_SRCROOT}/rust/target/x86_64-apple-ios/release',
  'LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*][arch=arm64]' => '${PODS_TARGET_SRCROOT}/rust/target/aarch64-apple-ios-sim/release',

  # link rust lib
  'OTHER_LIBTOOLFLAGS' => '-lopaque_rust',
}

Pod::Spec.new do |s|
  s.name         = "react-native-opaque"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "15.1" }
  s.source       = { :git => "https://github.com/serenity-kit/react-native-opaque.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm}", "cpp/**/*.{h,cpp}"

  s.dependency "React-Core"

  # New Architecture (Fabric / TurboModules) — RCT-Folly and boost are no
  # longer required in RN 0.73+.
  if ENV['RCT_NEW_ARCH_ENABLED'] == '1' then
    s.compiler_flags = "-DRCT_NEW_ARCH_ENABLED=1"
    s.pod_target_xcconfig = {
        "CLANG_CXX_LANGUAGE_STANDARD" => "c++17",
        **rustlib_xcconfig
    }
    s.dependency "React-Codegen"
    s.dependency "RCTRequired"
    s.dependency "RCTTypeSafety"
    s.dependency "ReactCommon/turbomodule/core"
  else
    s.pod_target_xcconfig = rustlib_xcconfig
  end

end
