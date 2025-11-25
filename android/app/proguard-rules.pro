# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }

# Google Play Core
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Device Apps
-keep class fr.g123k.deviceapps.** { *; }
-dontwarn fr.g123k.deviceapps.**

# Other dependencies
-keep class com.google.api.client.** { *; }
-dontwarn com.google.api.client.**
-keep class com.airbnb.lottie.** { *; }
-dontwarn com.airbnb.lottie.**
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keep class com.google.fonts.** { *; }
-dontwarn com.google.fonts.**
-keep class androidx.preference.** { *; }
-dontwarn androidx.preference.**
-keep class androidx.core.app.** { *; }
-dontwarn androidx.core.app.**
-keep class com.google.gson.** { *; }
-dontwarn.**