// 热更新 Demo 应用：只演示版本清单配置、检查更新、进度回调和打开游戏。
plugins {
    id("com.android.application")
}

android {
    namespace = "com.eath.cocosgamehotupdatedemo"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.eath.cocosgamehotupdatedemo"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
        // Demo 专用版本清单，与正式宿主使用的清单互相独立。
        buildConfigField("String", "MODULE_CATALOG_URL", "\"https://cocos-game-modules.pages.dev/demo/android/catalog.json\"")
        // 清单签名公钥（可公开），SDK 用它校验 catalog.json.sig；可用 -PmoduleCatalogPublicKey=... 覆盖
        val moduleCatalogPublicKey = providers.gradleProperty("moduleCatalogPublicKey")
            .orElse("MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAErTdV8F92qHswr8ysK3qdPAlCSlOGceiYNZu02CJbHkGYFCbrUg/+TNJDPQNt+nSyS6oM9KIkh7o3+t2DcsyQuA==")
            .get()
        buildConfigField("String", "MODULE_CATALOG_PUBLIC_KEY", "\"$moduleCatalogPublicKey\"")
        buildConfigField("String", "GAME_WS_URL", "\"wss://test.imnono.net/game-ws/ws\"")
        buildConfigField("String", "GAME_API_URL", "\"https://test.imnono.net/game-lobby\"")
        buildConfigField("String", "GAME_GUEST_SCENE_ID", "\"3947124\"")
        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
}

dependencies {
    // 热更新模块按 SDK 版本精确匹配，升级 SDK 后需要发布对应版本的模块。
    val gameSdkVersion = providers.gradleProperty("gameSdkVersion")
        .orElse("0.5.0")
        .get()
    // 热更新库会自动带上同版本的 game-sdk。
    implementation("com.eath.cocosgamesdk:game-sdk-hotupdate:$gameSdkVersion")
}
