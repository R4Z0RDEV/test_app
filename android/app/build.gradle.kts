import java.util.Properties
import java.io.FileInputStream
import org.jetbrains.kotlin.gradle.dsl.JvmTarget // jvmTarget 경고 해결용

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.erickong08.freeaicreation"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        val debugConfig = signingConfigs.getByName("debug")
        
        // properties 파일 로드
        val properties = Properties()
        val propsFile = project.rootProject.file("key.properties")
        
        if (propsFile.exists()) {
            FileInputStream(propsFile).use { properties.load(it) }
        }

        create("release") {
            val keystorePath = properties.getProperty("storeFile")
            val releaseStoreFile = if (keystorePath != null) project.rootProject.file(keystorePath) else null
            
            if (releaseStoreFile != null && releaseStoreFile.exists()) {
                storeFile = releaseStoreFile
                storePassword = properties.getProperty("storePassword")
                keyAlias = properties.getProperty("keyAlias")
                keyPassword = properties.getProperty("keyPassword")
            } else {
                project.logger.lifecycle("⚠️ Release keystore '$releaseStoreFile' not found. Falling back to debug keystore.")
                storeFile = debugConfig.storeFile
                storePassword = debugConfig.storePassword
                keyAlias = debugConfig.keyAlias
                keyPassword = debugConfig.keyPassword
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.erickong08.freeaicreation"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")
            
            // [추가] R8 (ProGuard) 설정
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.arthenica:ffmpeg-kit-full-gpl:6.0-2")
}

configurations.all {
    exclude(group = "com.arthenica", module = "ffmpeg-kit-https")
}
