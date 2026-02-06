# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Chaquopy
-keep class com.chaquo.python.** { *; }
-keep class python.** { *; }

# Google Sign-In
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }

# Isar
-keep class dev.isar.** { *; }

# FFmpeg Kit
-keep class com.arthenica.** { *; }

# ML Kit
-keep class com.google.mlkit.** { *; }

# Google Play Core (deferred components)
-dontwarn com.google.android.play.core.**

# ML Kit optional language scripts
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
