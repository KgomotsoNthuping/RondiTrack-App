import java.util.Base64

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val appDefines = (project.findProperty("dart-defines") as? String)
    .orEmpty()
    .split(",")
    .filter { it.isNotBlank() }
    .associate { encoded ->
        val entry = String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
        val parts = entry.split("=", limit = 2)
        parts[0] to parts.getOrElse(1) { "" }
    }

val firebaseResources = mapOf(
    "FIREBASE_APP_ID" to "google_app_id",
    "FIREBASE_API_KEY" to "google_api_key",
    "FIREBASE_MESSAGING_SENDER_ID" to "gcm_defaultSenderId",
    "FIREBASE_PROJECT_ID" to "project_id"
)

val firebaseConfigured = firebaseResources.keys.count {
    !appDefines[it].isNullOrBlank()
}

require(firebaseConfigured == 0 || firebaseConfigured == firebaseResources.size) {
    "Supply all four Firebase defines, or omit all four."
}

android {
    namespace = "za.co.kgomotsonthuping.ronditrack"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "za.co.kgomotsonthuping.ronditrack"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        if (firebaseConfigured == firebaseResources.size) {
            firebaseResources.forEach { (key, resource) ->
                resValue("string", resource, appDefines.getValue(key).trim())
            }
        }
    }

    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "RondiTrack Dev"
            manifestPlaceholders["deepLinkScheme"] = "ronditrack-dev"
        }

        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            manifestPlaceholders["appLabel"] = "RondiTrack Staging"
            manifestPlaceholders["deepLinkScheme"] = "ronditrack-staging"
        }

        create("prod") {
            dimension = "environment"
            manifestPlaceholders["appLabel"] = "RondiTrack"
            manifestPlaceholders["deepLinkScheme"] = "ronditrack-prod"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}