// 热更新 Demo 工程配置：SDK 从公开 Maven 仓库拉取，可用 -PgameSdkRepositoryUrl 指向本地仓库调试。
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    val gameSdkRepositoryUrl = providers.gradleProperty("gameSdkRepositoryUrl")
        .orElse("https://raw.githubusercontent.com/eathwinster-jk/cocos-game-android-sdk/main/repository")
        .get()
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri(gameSdkRepositoryUrl)
        }
    }
}
rootProject.name = "CocosGameHotUpdateAndroidDemo"
include(":app")
