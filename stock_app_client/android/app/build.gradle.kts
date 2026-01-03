plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.stock_app"
    compileSdk = 36
    // 不指定 NDK 版本，让项目在没有 NDK 的情况下构建

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.stock_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion  // 明确指定 minSdk，修复 SharedPreferences 通道错误
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // 移除 NDK 配置以避免下载问题
    }

    buildTypes {
        debug {
            // Debug模式优化：禁用混淆和压缩以加快构建
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }

    // 禁用不需要的构建功能以加快速度
    buildFeatures {
        aidl = false
        renderScript = false
        resValues = false
        shaders = false
    }
    
    // 明确禁用 NDK 和 CMake
    externalNativeBuild {
    }

    // 只构建需要的ABI（调试时只构建arm64-v8a）
    splits {
        abi {
            isEnable = false
        }
    }

    // 打包选项优化
    packagingOptions {
        resources {
            excludes += setOf("META-INF/NOTICE", "META-INF/LICENSE", "META-INF/*.kotlin_module")
        }
    }
}

dependencies {
    // Core library desugaring for Java 8+ APIs
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
