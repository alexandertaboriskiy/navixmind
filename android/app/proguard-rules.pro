# Flutter wrapper - keep everything
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Pigeon (used by path_provider, etc.)
-keep class dev.flutter.pigeon.** { *; }
-keep class **.Pigeon* { *; }
-keep class **.*Api { *; }
-keep class **.*Api$* { *; }

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Connectivity Plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# File Picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Share Plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# InAppWebView
-keep class com.pichillilorenzo.flutter_inappwebview_android.** { *; }

# Chaquopy
-keep class com.chaquo.python.** { *; }
-keep class python.** { *; }

# Google Sign-In
-keep class com.google.android.gms.** { *; }
-keep class io.flutter.plugins.googlesignin.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }

# Isar
-keep class dev.isar.** { *; }

# FFmpeg Kit
-keep class com.arthenica.** { *; }
-keep class com.antonkarpenko.ffmpegkit.** { *; }

# ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_face_detection.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Google Play Core (deferred components)
-dontwarn com.google.android.play.core.**

# ML Kit optional language scripts
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Optimize aggressively - remove unused code paths
-optimizationpasses 5
-allowaccessmodification
-repackageclasses ''
