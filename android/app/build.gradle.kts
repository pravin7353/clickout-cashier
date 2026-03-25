import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// 🔥 FIX: Ye code version number dhoondh kar layega
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode")
val flutterVersionName = localProperties.getProperty("flutter.versionName")

android {
    namespace = "com.example.clickout_cashier"
    
    // 🔥 FIX: Zabardasti Naya Version Use Karo
    compileSdk = 36
    buildToolsVersion = "34.0.0" 

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17 // ✅ NEW
        targetCompatibility = JavaVersion.VERSION_17 // ✅ NEW
    }

    kotlinOptions {
        jvmTarget = "17" // ✅ NEW
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "com.example.clickout_cashier"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        
        // 🔥 FIX: Ab yahan error nahi aayega
        versionCode = flutterVersionCode?.toInt() ?: 1
        versionName = flutterVersionName ?: "1.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
