# Flutter-specific rules
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep the names of classes used by Flutter plugins
-keep class com.multicloud.multicloud.** { *; }

# Prevent obfuscation of classes that are referenced in XML
-keepclassmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}

# Preserve entry points for your app
-keep public class * extends android.app.Application
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Preserve Gson serialized classes
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Preserve classes referenced in native libraries
-keepclasseswithmembers class * {
    native <methods>;
}

# Optional: Rules for common libraries (add based on dependencies)
# For Retrofit (if used):
-dontwarn okhttp3.**
-keep class retrofit2.** { *; }
-keepattributes Signature
-keepattributes Exceptions

# For Firebase (if used):
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# extra
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# Keep Flutter assets
-keep class **.R
-keep class **.R$* { *; }
-keep class io.flutter.** { *; }
