import java.util.Properties
import java.io.FileInputStream
 
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.podcast_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.podcast_player"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 簽章設定：若有 key.properties 則使用 release 簽章，否則退回 debug 簽章
    val keystoreProperties = Properties()
    val candidateKeyProps = listOf(
        project.file("key.properties"),            // android/app/key.properties
        rootProject.file("key.properties"),        // 專案根目錄
        rootProject.file("android/key.properties") // android/key.properties
    )
    val keystorePropertiesFile = candidateKeyProps.firstOrNull { it.exists() }
    if (keystorePropertiesFile != null && keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile != null && keystorePropertiesFile.exists()) {
                val alias = keystoreProperties["keyAlias"] as String?
                val keyPassword = keystoreProperties["keyPassword"] as String?
                val storePassword = keystoreProperties["storePassword"] as String?
                val storeFilePath = keystoreProperties["storeFile"] as String?

                if (alias != null && keyPassword != null && storePassword != null && storeFilePath != null) {
                    this.keyAlias = alias
                    this.keyPassword = keyPassword
                    this.storePassword = storePassword
                    this.storeFile = file(storeFilePath)
                }
            }
        }
    }

    buildTypes {
        release {
            // 若 key.properties 存在即使用 release 簽章，否則沿用 debug 簽章以確保可建置
            signingConfig = if (keystorePropertiesFile != null && keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
