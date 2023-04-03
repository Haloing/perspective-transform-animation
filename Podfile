# Uncomment the next line to define a global platform for your project

source 'https://mirrors.tuna.tsinghua.edu.cn/git/CocoaPods/Specs.git'

# platform :ios, '9.0'

  pod 'RxSwift', '6.5.0'
  pod 'RxCocoa', '6.5.0'
  pod 'OpenCV', '~> 4.3.0'
  pod 'Toast-Swift', '~> 5.0.1'

  # 透视变换动画
  pod 'PerspectiveTransform'

target 'perspective-transform-animation' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for perspective-transform-animation
  
  post_install do |installer|
    installer.pods_project.build_configurations.each do |config|
      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
    end
  end
  
end
