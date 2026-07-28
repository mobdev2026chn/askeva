# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ML Kit Text Recognition
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.ml.** { *; }
-dontwarn com.google.android.gms.internal.ml.**

# Vision API
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.gms.common.internal.safeparcel.SafeParcelable { *; }

# Ignore missing optional script recognizers that cause R8 failures
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Play Core (Deferred Components) - Safe to ignore if not using them
-dontwarn com.google.android.play.core.**

# General warnings
-dontwarn java.lang.invoke.**
-dontwarn **$$Lambda$**
