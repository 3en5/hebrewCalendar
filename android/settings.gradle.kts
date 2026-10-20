pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    // 2.2: reads the metadata of libraries built with Kotlin 2.3
    // (firebase-auth 24.1, warning in the 2026-10-20 build); a 2.1 compiler
    // only reads up to 2.2.
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    // Reads android/app/google-services.json at build time (M2b — Firebase
    // wiring). Applied (without a version) in android/app/build.gradle.kts.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
