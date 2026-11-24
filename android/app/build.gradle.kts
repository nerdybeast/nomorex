plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nomorex.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The production id; the local and beta flavors add a suffix below, so
        // all three can be installed side by side.
        applicationId = "com.nomorex.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // sentry_flutter 10 requires API 26; Flutter's default is lower.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // One flavor per environment (local, beta, production), matching APP_ENV.
    // The names are checked against each other at startup (see
    // assertFlavorMatchesEnvironment). Not named "test": Gradle reserves it.
    flavorDimensions += "environment"
    productFlavors {
        create("local") {
            dimension = "environment"
            applicationIdSuffix = ".local"
            manifestPlaceholders["appLabel"] = "NoMoreX (Local)"
        }
        create("beta") {
            dimension = "environment"
            applicationIdSuffix = ".beta"
            manifestPlaceholders["appLabel"] = "NoMoreX (Beta)"
        }
        create("production") {
            dimension = "environment"
            manifestPlaceholders["appLabel"] = "NoMoreX"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// Only the beta flavor has a Firebase config (src/beta/google-services.json).
// Local sends no telemetry and production's Firebase project doesn't exist yet,
// so a missing file is fine for them. A test (test/analytics) checks that the
// beta file is present and matches lib/firebase_options.dart, so it can't go
// missing unnoticed.
googleServices {
    missingGoogleServicesStrategy = com.google.gms.googleservices.GoogleServicesPlugin.MissingGoogleServicesStrategy.IGNORE
}

flutter {
    source = "../.."
}

// SPIKE (#183): Gemini Nano through the ML Kit GenAI Prompt API.
dependencies {
    implementation("com.google.mlkit:genai-prompt:1.0.0-beta5")
}
