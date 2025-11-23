# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# FFmpeg Kit
-dontwarn com.arthenica.ffmpegkit.**
-keep class com.arthenica.ffmpegkit.** { *; }
-keep interface com.arthenica.ffmpegkit.** { *; }
-keep enum com.arthenica.ffmpegkit.** { *; }

# Video Player
-dontwarn io.flutter.plugins.videoplayer.**

# Google Play Core (Flutter Deferred Components)
-dontwarn com.google.android.play.core.**
