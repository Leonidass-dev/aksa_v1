# Flutter / Firebase için ProGuard kuralları (Release build)

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
-keep class io.flutter.embedding.** { *; }

# Health Connect
-keep class androidx.health.connect.** { *; }
-dontwarn androidx.health.connect.**

# JSON / Gson (Firebase'in iç kullanımı)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }

# Kotlin Coroutines
-dontwarn kotlinx.coroutines.**

# AndroidX
-keep class androidx.** { *; }
-dontwarn androidx.**

# R8 uyumluluğu
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
