plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// flutter_background_geolocation: strips the library's debug sounds from
// release builds.
val backgroundGeolocation = project(":flutter_background_geolocation")
apply { from("${backgroundGeolocation.projectDir}/background_geolocation.gradle") }

android {
    namespace = "yool.live.app"
    compileSdk = 37
    ndkVersion = "27.0.12077973"

    // telegramLoginHost() below
    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("KEYSTORE_PATH") ?: "upload-keystore.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }

    defaultConfig {
        applicationId = "yool.live.app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // The tracking library's licence (release builds; debug runs
        // without one). CI passes it from a secret.
        manifestPlaceholders["bgLicenseKey"] = System.getenv("BG_LICENSE_KEY") ?: ""
        // Where Telegram sends the driver after "Log In" (Telegram's domain
        // for the app signed with the debug key). TelegramAuthService asks
        // MainActivity for it.
        telegramLoginHost("app3297224938-login.tg.dev")
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Telegram verifies its domain against the key the installed app
            // is signed with. An app bundle goes to Google Play and is
            // re-signed with Play's key; an APK keeps our upload key (builds
            // installed by hand).
            val forPlay = gradle.startParameter.taskNames.any { it.contains("bundle", ignoreCase = true) }
            telegramLoginHost(if (forPlay) "app1451611780-login.tg.dev" else "app1340816991-login.tg.dev")
            // Required by the tracking library, resource shrinking off.
            isMinifyEnabled = true
            isShrinkResources = false
            proguardFiles("proguard-rules.pro")
        }
    }
}

// One value for the App Link in the manifest and for the app's redirect_uri.
fun com.android.build.api.dsl.VariantDimension.telegramLoginHost(host: String) {
    manifestPlaceholders["telegramLoginHost"] = host
    resValue("string", "telegram_login_host", host)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
