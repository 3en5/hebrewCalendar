import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Processes google-services.json (M2b — Firebase wiring); version
    // declared in android/settings.gradle.kts.
    id("com.google.gms.google-services")
}

// M7 (docs/RELEASE.md): the real release keystore/credentials live outside
// the repo in android/key.properties (gitignored — RULES.md §5.4), written
// by a developer locally or by .github/workflows/release.yml from GitHub
// Secrets. When that file is absent (every other build: local `flutter run
// --release`, CI's debug-only jobs, a contributor who hasn't generated a
// release key), the release build type falls back to the committed debug
// signing config below so those builds keep working unchanged.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
val keystoreProperties = Properties()
if (hasReleaseSigning) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "il.co.natanor.kalfapp.hebrewcalendar"
    compileSdk = flutter.compileSdkVersion
    // Firebase plugins (firebase_core/auth, cloud_firestore, google_sign_in)
    // require NDK 27; flutter.ndkVersion is older.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // flutter_local_notifications (M4) requires core library desugaring
        // (java.time backport on minSdk 23) — build fails at
        // checkDebugAarMetadata without it.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "il.co.natanor.kalfapp.hebrewcalendar"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Raised from flutter.minSdkVersion (21): firebase_auth's Android
        // implementation declares minSdkVersion 23 (M2b — Firebase wiring);
        // then to 24, which Play's automatic app protection requires.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Deterministic debug keystore committed to the repo so every build
        // (local or CI) carries the same SHA-1 — the one registered in the
        // Firebase console. Without this, Google Sign-In fails on APKs built
        // on other machines/runners. Debug-only key; the release key is
        // separate and secret (M7, below).
        getByName("debug") {
            storeFile = rootProject.file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        // M7: only registered when android/key.properties actually exists,
        // so a checkout without a release keystore doesn't fail Gradle sync
        // just from referencing a missing file.
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // M7: real release signing when android/key.properties is
            // present (a developer's local `flutter build appbundle
            // --release`, or .github/workflows/release.yml); falls back to
            // the committed debug key otherwise, so `flutter run --release`
            // and every other build keep working unchanged (docs/RELEASE.md).
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // M7: shrink/obfuscate the release build. Keep rules for the
            // plugins that need them (flutter_local_notifications,
            // workmanager, Firebase) live in proguard-rules.pro.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by isCoreLibraryDesugaringEnabled (flutter_local_notifications
    // needs desugar_jdk_libs >= 2.1.4).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
