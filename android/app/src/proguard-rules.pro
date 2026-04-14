# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keepattributes SourceFile,LineNumberTable

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.reflect.** { *; }
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}
-dontwarn kotlin.**

# Coroutines
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Workmanager (be.tramckrijte.workmanager)
-keep class be.tramckrijte.workmanager.** { *; }
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keepclassmembers class androidx.work.impl.** {
    *** *(...);
}

# Local Notifications (com.dexterous.flutterlocalnotifications)
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationCompat$* { *; }

# Permission Handler (com.baseflow.permissionhandler)
-keep class com.baseflow.permissionhandler.** { *; }
-keep class android.content.pm.** { *; }

# Hive (io.hive)
-keep class io.hive.** { *; }
-keepclassmembers class io.hive.** {
    public <methods>;
}

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class androidx.appcompat.app.AppCompatActivity { *; }

# Mobile Scanner / ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-keepclassmembers enum com.google.mlkit.common.model.** {
    **[] $VALUES;
    public *;
}

# Gson / JSON parsing
-keep class com.google.gson.** { *; }
-keepclassmembers class com.google.gson.** {
    public <methods>;
}
-keepattributes *Annotation*,EnclosingMethod
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.internal.$Gson$Types
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# HTTP Client / Dio
-keep class okhttp3.** { *; }
-keep class retrofit2.** { *; }
-keep class io.dio.** { *; }
-dontwarn okhttp3.**
-dontwarn retrofit2.**

# Shared Preferences (native_storage)
-keep class androidx.preference.** { *; }

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Flutter SVG
-keep class com.example.flutter_svg.** { *; }

# Device Info Plus
-keep class io.flutter.plugins.deviceinfoplus.** { *; }

# Firebase (если используется)
-keep class com.google.firebase.** { *; }
-keep class com.google.firebase.auth.** { *; }
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# View & Lifecycle
-keep class androidx.lifecycle.** { *; }
-keep class androidx.fragment.app.** { *; }
-keep class androidx.appcompat.** { *; }

# Don't warn about missing classes
-dontwarn androidx.**
-dontwarn com.google.**
-dontwarn okhttp3.**
-dontwarn sun.misc.**

# Keep all enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep models для Hive
-keep class lib.models.** { *; }

# Keep BLoC
-keep class lib.blocs.** { *; }

# Verbose output
-verbose
