# M7 release ProGuard/R8 rules (docs/RELEASE.md), applied only to the
# `release` build type once android/key.properties exists (see
# android/app/build.gradle.kts — isMinifyEnabled/isShrinkResources are only
# turned on there). Most of the Firebase/AndroidX AARs already ship their
# own consumer-proguard rules that R8 merges in automatically; the rules
# below are the ones the task brief specifically calls out as needed on top
# of that, for plugins this app actually uses.

# flutter_local_notifications (M4, v20.1.0): its own example proguard file
# notes the old Gson-serialization keep rules are obsolete as of v19+, but
# its platform-channel method handler classes still need to survive
# shrinking/obfuscation.
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# workmanager (M5b, v0.9.0+3): `BackgroundWorker` resolves the registered
# Dart callback dispatcher from a background isolate/process
# (lib/features/settings/application/background_sync_bootstrap.dart) — its
# classes and AndroidX WorkManager's own must not be renamed or stripped.
-keep class dev.fluttercommunity.workmanager.** { *; }
-keep class androidx.work.** { *; }

# Firebase (firebase_core/firebase_auth/cloud_firestore, M2b) and
# google_sign_in (also M2b, backed by Google Play Services auth): defensive
# backstop for the reflection/Parcelable-heavy internals of these SDKs on
# top of whatever consumer rules the AARs already bundle.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
