# Firebase / Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Flutter's Play Store "deferred components" support references the
# play-core split-install classes even when the app doesn't use deferred
# components at all (no dynamic feature modules here). Since we don't
# depend on play-core, R8 can't resolve these — safe to suppress, this is
# a known, common Flutter/AGP interaction, not a real missing dependency.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }

# Dio / OkHttp (networking)
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Gson-style reflection used by some Firebase/Play Services internals
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# Telephony plugin (SMS)
-keep class com.shounakmulay.telephony.** { *; }

# Keep default Flutter/Play Core rules that flutter_local_notifications
# and deferred-components style plugins sometimes expect to find.
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
