plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.jackh0006.bnb_wallet_gui"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.jackh0006.bnbwallet"
        // Android 8.0 (API 26) supports devices such as the Huawei Y9 2019
        // while retaining modern platform encryption and TLS capabilities.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Arm64-only release: replace the Flutter plugin's default ABI set
        // (armeabi-v7a + arm64-v8a + x86_64) with arm64-v8a only, so plugin
        // native libraries from other ABIs are excluded from the APK.
        ndk {
            abiFilters.clear()
            abiFilters.add("arm64-v8a")
        }
    }

    buildTypes {
        release {
            // Signed with apksigner (v3) by scripts/build-apk.sh; debug keys here
            // keep `flutter run --release` working during development.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
