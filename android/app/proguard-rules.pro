# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# ============================================
# Flutter Local Notifications - CRITICAL RULES
# ============================================
# Keep all classes and members to prevent "Missing type parameter" error
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.** { *; }

# Specifically keep the BootReceiver and NotificationReceiver
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin { *; }

# Keep notification data classes with type parameters
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.models.** { *; }

# Keep all classes in the notification package
-keep class com.dexterous.** { *; }

# ============================================
# Generic Type Information - CRITICAL
# ============================================
# Preserve generic signatures for type parameters (prevents "Missing type parameter" error)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations

# ============================================
# Android Components
# ============================================
# Keep all notification-related classes
-keep class * extends android.content.BroadcastReceiver { *; }
-keep class * extends android.app.Service { *; }

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# Keep all serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ============================================
# Gson (if used for serialization)
# ============================================
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ============================================
# Google Play Core (SplitCompat) - Optional
# ============================================
# These classes are optional and only needed for deferred components
# If not using deferred components, we can safely ignore these warnings
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Keep Flutter deferred component classes if they exist
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }

# ============================================
# Google Play Core (SplitCompat) - Optional
# ============================================
# These classes are optional and only needed for deferred components
# If not using deferred components, we can safely ignore these warnings
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Keep Flutter deferred component classes if they exist
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }

# ============================================
# HTTP and Network Classes - CRITICAL for API calls
# ============================================
# Keep HTTP client classes
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep HTTP package classes
-keep class java.net.** { *; }
-keep class javax.net.** { *; }

# Keep InternetConnectionChecker classes
-keep class com.github.** { *; }
-dontwarn com.github.**

# Keep all classes that use HTTP
-keep class * extends java.net.HttpURLConnection { *; }

# Keep JSON parsing classes (for API responses)
-keep class org.json.** { *; }

# Keep classes with @Keep annotation
-keep @androidx.annotation.Keep class *
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# ============================================
# Other Important Rules
# ============================================
# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep R class
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Keep application class
-keep public class * extends android.app.Application

# Preserve line numbers for stack traces
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
