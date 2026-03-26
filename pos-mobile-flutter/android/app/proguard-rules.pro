# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter references Play Core for deferred components — not used in this app
-dontwarn com.google.android.play.core.**

# Keep model classes (used with jsonDecode reflection)
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# mobile_scanner / MLKit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
