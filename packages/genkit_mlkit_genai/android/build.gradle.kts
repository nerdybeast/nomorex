// The app's Gradle supplies the Android Gradle Plugin (and, from AGP 9, its
// built-in Kotlin), so this declares no buildscript of its own: a second AGP on
// the classpath breaks the build.
plugins {
    id("com.android.library")
}

group = "com.nomorex.genkit_mlkit_genai"
version = "1.0-SNAPSHOT"

android {
    namespace = "com.nomorex.genkit_mlkit_genai"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The app's own minimum. ML Kit reports devices it can't run on as
        // unavailable at runtime; Gemini Nano itself needs a recent flagship.
        minSdk = 26
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Gemini Nano through AICore. Beta: the version the #183 spike built with.
    implementation("com.google.mlkit:genai-prompt:1.0.0-beta5")
    // Pigeon's generated host API runs its suspend functions in coroutines.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}
