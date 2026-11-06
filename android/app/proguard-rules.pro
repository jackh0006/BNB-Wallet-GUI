# ProGuard rules for X Wallet GUI (Android release).

# Keep Flutter engine and plugin entry points.
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep GeneratedPluginRegistrant.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# web3dart / pointycastle / sec
-keep class org.bouncycastle.** { *; }
-keep class web3dart.** { *; }
-keep class sec.** { *; }

# Flutter secure storage
-keep class vn.hunghd.fluttersecurestorage.** { *; }

# Keep names used reflectively by Flutter.
-keepclassmembers class * extends io.flutter.embedding.engine.plugins.FlutterPlugin {
    public <init>();
}

# Do not obfuscate our app package heavily where reflection is used.
-keep class com.jackh0006.bnbwallet.MainActivity { *; }

# Flutter embedding references Play Store split-install classes that are not
# present in this environment and not used by the app. Allow R8 to proceed.
-dontwarn com.google.android.play.core.**
