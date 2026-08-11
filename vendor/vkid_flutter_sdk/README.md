# vkid_flutter_sdk
<div align="center">
  <h1 align="center">
    <img src="https://raw.githubusercontent.com/VKCOM/vkid-android-sdk/master/logo.svg" width="150" alt="VK ID SDK Logo">
  </h1>
  <p align="center">
   VK ID SDK for Flutter is the most comprehensive library for user authentication via VK ID, officially supported by VK.
  </p>
</div>

The SDK includes an API for OAuth 2.1 authorization, allows integration of VK ID elements, including one tap login buttons using VK, Mail and OK accounts as well as popups with similar functionality, and enables access to user data.

## Requirements

* Flutter version `3.10.6` or later
* Dart version matching Flutter version `3.0.6` or later

Make sure to also check the platform-specific limitations.

### Android
* `Android SDK` `21` or later
* `Java` `11` or later
* `Kotlin` `2.0.20` or later

### iOS
* `iOS` `12.0` or later
* `Swift` `5.9` or later
* `Xcode` `15.2` or later

## SDK installation

Run the following command:
```
flutter pub add vkid_flutter_sdk
```

This will add the following text to your pubspec.yaml:
```
dependencies:
    vkid_flutter_sdk: 1.0.3
```
You can also manually add the provided text to your pubspec.yaml without running the `flutter pub add` command.

## Documentation

- [What is VK ID](https://id.vk.ru/about/business/go/docs/en/vkid/latest/vk-id/intro/start-page)
- [Creating an app](https://id.vk.ru/about/business/go/docs/en/vkid/latest/vk-id/connection/create-application)
- [Design requirements](https://id.vk.ru/about/business/go/docs/en/vkid/latest/vk-id/connection/guidelines/design-rules-oauth)

## Demo

### Install Flutter
https://docs.flutter.dev/get-started/install

#### Change the Flutter version
```shell
cd /your/path/to/flutter
git checkout 3.10.6
flutter --version
```

##### iOS SPM usage
if you are using SPM for development you need to use Flutter version 3.24 or higher.
```shell
cd /your/path/to/flutter
git checkout 3.24
flutter --version
```
To turn on SPM using:
```shell
flutter config --enable-swift-package-manager
```
To disabe SPM:
```shell
flutter config --no-enable-swift-package-manager
```

### Download the project and run the demo
1. Check that all necessary Flutter components are installed.
```shell
flutter doctor
```
2. View the list of available emulators and simulators.
```shell
flutter emulators
```
3. Create an emulator or simulator if none are available.
```shell
flutter emulators --create --name example_emulator
```
4. Launch the emulator or simulator.
```shell
flutter emulators --launch example_emulator
```
5. Add parameters for **sample**.

Android:
Add the following to the `example/android/local.properties` file:
```
VKIDClientSecret=YOUR_CLIENT_SECRET
VKIDClientID=YOUR_CLIENT_ID
```

iOS:
Add the following to the `example/ios/AppCredentials.xcconfig` file:
```
VK_APP_CLIENT_ID=YOUR_CLIENT_ID
VK_APP_CLIENT_SECRET=YOUR_CLIENT_SECRET
```

**YOUR_CLIENT_SECRET** and **YOUR_CLIENT_ID** are data generated in the VK ID authorization service when creating an app. They are stored there as well, in the [App](https://id.vk.ru/about/business/go/accounts/) section.

6. Install iOS dependencies.
##### Cocoapods
For installing cocoapods dependencies use:
```shell
flutter pub get
cd example/ios
pod install --repo-update
cd ../../
```

##### SPM
For using SPM
```shell
flutter pub get
```

If you were using Cocoapods previously, we recommend you to clean 'Pods' folder to prevent issues that may occur.
```shell
rm -r example/ios/Pods
```

7. Run the demo in the **example** directory.
```shell
cd example
flutter run
```