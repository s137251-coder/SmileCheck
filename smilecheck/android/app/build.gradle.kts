import java.util.Properties

// Release signing is opt-in. CI and `flutter run --release` have no keystore,
// so a missing key.properties falls back to debug keys rather than failing the
// build; the warning below makes sure that is never silent.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasReleaseKeystore) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

// Reading through this rather than casting directly turns a missing or
// mistyped entry into a message that names the problem. The BOM case is worth
// calling out: a key.properties saved as UTF-8-with-BOM parses its first key as
// "﻿storeFile", and the raw failure is an unexplained null cast.
fun keystoreProperty(name: String): String =
    (keystoreProperties[name] as String?)?.trim()?.takeIf { it.isNotEmpty() }
        ?: throw GradleException(
            "android/key.properties has no value for '$name'. " +
                "See android/key.properties.example. If the file was created " +
                "on Windows, check it was saved as UTF-8 without a BOM."
        )

if (!hasReleaseKeystore) {
    logger.lifecycle(
        "SmileCheck: no android/key.properties found. Release builds will be " +
            "signed with debug keys and cannot be uploaded to Google Play."
    )
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.smilecheck"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.smilecheck.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                // Paths in key.properties are resolved against android/, so a
                // keystore kept outside the repo can be referenced directly.
                storeFile = rootProject.file(keystoreProperty("storeFile"))
                storePassword = keystoreProperty("storePassword")
                keyAlias = keystoreProperty("keyAlias")
                keyPassword = keystoreProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    jvmToolchain(17)
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
