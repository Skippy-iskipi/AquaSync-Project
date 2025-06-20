# AquaSync

A marine fish data collection and compatibility assessment tool.

## Real-Time Fish Detection Setup

To enable the real-time fish detection feature, follow these steps:

1. Run the following command to install the required dependencies:
   ```
   flutter pub get
   ```

2. For Android, update your app/build.gradle to support ML Kit:
   ```gradle
   android {
       defaultConfig {
           // ...
           minSdkVersion 21
       }
   }
   ```

3. For iOS, add the following to your Podfile:
   ```ruby
   platform :ios, '12.0'
   
   # Add this line at the top of your Podfile:
   use_frameworks!
   
   post_install do |installer|
     installer.pods_project.targets.each do |target|
       target.build_configurations.each do |config|
         config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
       end
     end
   end
   ```

4. For Android, add the following permissions to your AndroidManifest.xml:
   ```xml
   <uses-permission android:name="android.permission.CAMERA" />
   <uses-feature android:name="android.hardware.camera" />
   <uses-feature android:name="android.hardware.camera.autofocus" />
   ```

5. For iOS, add the following to your Info.plist:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>We need access to your camera to detect fish species in real-time.</string>
   ```

## Features

- Real-time fish detection in camera view
- Fish species identification from photos
- Detailed information about fish species
- Fish compatibility assessment
- Aquarium setup recommendations

## Getting Started

This project is a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
