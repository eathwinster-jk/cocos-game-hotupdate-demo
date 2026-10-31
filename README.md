# Cocos 游戏模块热更新接入文档

本仓库是游戏模块热更新的独立接入文档和 Demo，包含 Android 和 iOS 两个精简宿主，只演示热更新相关接口。游戏 SDK 的完整接入（登录会话、下注、记录等）请参考各平台 SDK 文档。

- Android Demo：[`android/`](android/)
- iOS Demo：[`ios/`](ios/)

## 1. 概述

游戏玩法以 Cocos Bundle（游戏模块）的形式内置在 SDK 中。开启热更新后，游戏方可以单独发布新的游戏模块，宿主无需升级 SDK、无需发版即可让用户用上新版本。

工作方式：

1. 宿主打开游戏时，SDK 使用本机已安装的最新模块；没有安装过就使用 SDK 内置的模块。
2. 同时在后台拉取版本清单，有新版本就下载、校验并安装。
3. 新版本在**下次打开游戏**时生效，不会打断当前正在玩的游戏。

适用平台：Android、iOS。H5 SDK 每次都从网页加载最新资源，不需要热更新。

## 2. 版本要求

| 平台 | 最低 SDK 版本 |
| --- | --- |
| Android | `com.eath.cocosgamesdk:game-sdk:0.2.5` |
| iOS | `cocos-game-ios-sdk` 0.2.5 |

游戏模块依赖 SDK 内置的主包脚本，**只适用于构建它的那个 SDK 版本**。宿主升级 SDK 后，SDK 只会安装为新 SDK 版本发布的模块；在游戏方发布之前，使用新 SDK 内置的模块。

## 3. 宿主接入

只需要在初始化 SDK 时传入版本清单地址。不传就不开启热更新，行为与 0.2.4 及以前一致。

版本清单地址由游戏方提供，必须是 HTTPS，并且 Android、iOS 各用一份。

### 3.1 Android

```java
CocosGameSDK sdk = CocosGameSDK.getInstance();
sdk.initialize(context, new GameSDKConfig("https://<清单域名>/android/catalog.json"));

// 可选：监听更新进度，回调在主线程
sdk.setUpdateListener(new GameUpdateListener() {
    @Override
    public void onUpdateProgress(String gameId, String state, long receivedBytes, long totalBytes) {
        Log.i("Host", "更新进度 " + gameId + " " + state + " " + receivedBytes + "/" + totalBytes);
    }

    @Override
    public void onUpdateFailed(String gameId, int code, String message) {
        Log.w("Host", "更新失败 " + gameId + " code=" + code + " " + message);
    }
});

// 可选：在打开游戏之前预先下载，例如进入直播间时
sdk.checkGameUpdate("niuniu");
```

页面销毁时调用 `setUpdateListener(null)`，避免监听器持有已销毁的页面。

### 3.2 iOS

```objc
[[CocosGameSDK shared] initializeWithWindow:self.window launchOptions:launchOptions];
NSURL *catalogURL = [NSURL URLWithString:@"https://<清单域名>/ios/catalog.json"];
[[CocosGameSDK shared] configure:[[CocosGameSDKConfig alloc] initWithCatalogURL:catalogURL]];

// 可选：在打开游戏之前预先下载
[[CocosGameSDK shared] checkGameUpdate:@"niuniu"];
```

更新进度通过 `CocosGameSDKDelegate` 的可选方法回调，均在主线程：

```objc
- (void)gameSDKDidUpdateGame:(NSString *)gameId
                       state:(NSString *)state
               receivedBytes:(NSUInteger)receivedBytes
                  totalBytes:(NSUInteger)totalBytes {
    NSLog(@"更新进度 %@ %@ %lu/%lu", gameId, state, (unsigned long)receivedBytes, (unsigned long)totalBytes);
}

- (void)gameSDKDidFailUpdateGame:(NSString *)gameId code:(NSInteger)code message:(NSString *)message {
    NSLog(@"更新失败 %@ code=%ld %@", gameId, (long)code, message);
}
```

### 3.3 回调说明

更新进度的 `state` 取值：

| state | 含义 | receivedBytes / totalBytes |
| --- | --- | --- |
| `checking` | 正在拉取版本清单 | 0 / 0 |
| `downloading` | 正在下载模块包 | 已下载 / 总大小（字节） |
| `installed` | 新版本已安装，下次打开游戏生效 | 总大小 / 总大小 |
| `upToDate` | 没有可安装的新版本 | 0 / 0 |

失败回调的错误码：

| code | 含义 |
| --- | --- |
| 1 | 网络错误：清单或模块包下载失败、HTTP 状态码非 200 |
| 2 | 版本清单格式错误 |
| 3 | 模块包校验失败：大小或 SHA-256 与清单不一致 |
| 4 | 安装失败：解压、写入或磁盘空间问题 |

**更新失败不会影响打开游戏**，SDK 会继续使用已安装的版本或内置版本。宿主一般只需要记录日志，不需要提示用户。

### 3.4 宿主需要注意的事项

- 打开游戏时 SDK 会自动检查更新，`checkGameUpdate` 只是提前下载，不调用也可以。
- 同一个游戏同时只会有一个下载任务，重复调用会被忽略。
- 模块存放位置由 SDK 管理，宿主不要清理或修改：
  - Android：`Context.getFilesDir()/cocos_game_modules/`
  - iOS：`Documents/cocos_game_modules/`（已排除 iCloud 备份）
- 宿主如果在清理缓存时删除了上述目录，SDK 会退回内置模块，下次打开游戏时重新下载。

## 4. 安全与容错机制

| 机制 | 说明 |
| --- | --- |
| 仅 HTTPS | 清单地址和模块包地址都必须是 HTTPS |
| 完整性校验 | 下载后校验大小和 SHA-256，不一致则丢弃 |
| 大小限制 | 单个模块包不超过 64 MB |
| 安全解压 | 拒绝写到模块目录以外的路径 |
| 原子安装 | 先解压到临时目录，校验通过后再切换为正式版本，中途失败不影响已安装版本 |
| 加载失败回退 | 新版本加载失败时，本次立即改用内置模块，并把该版本标记为坏版本，以后不再安装 |
| 启动确认 | 新版本连续 2 次打开都没有成功进入游戏，自动标记为坏版本，退回内置模块 |
| SDK 升级重置 | SDK 版本变化后，旧版本的模块和坏版本记录全部失效 |

## 5. 版本清单格式

每个平台一份 `catalog.json`：

```json
{
  "schemaVersion": 1,
  "modules": [
    {
      "gameId": "niuniu",
      "sdkVersion": "0.2.5",
      "version": 3,
      "url": "niuniu/0.2.5/3.zip",
      "sha256": "17a2bbd6b8e41aec6b1e839db1d0825c2e553656667f412da6dd4d585aca28ff",
      "size": 1818830
    }
  ]
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `schemaVersion` | 整数 | 固定为 1 |
| `gameId` | 字符串 | 游戏编号，同时也是 Bundle 名 |
| `sdkVersion` | 字符串 | 模块适用的 SDK 版本，必须与宿主集成的 SDK 版本完全一致 |
| `version` | 正整数 | 模块版本，只能递增 |
| `url` | 字符串 | 模块包地址，相对路径按清单地址解析，也可以写完整的 HTTPS 地址 |
| `sha256` | 字符串 | 模块包的 SHA-256，64 位十六进制 |
| `size` | 整数 | 模块包字节数，不超过 64 MB |

同一个 `gameId` + `sdkVersion` 只保留一条记录。SDK 只在 `version` 大于本机已安装版本、且不是坏版本时才安装。

缓存建议：`catalog.json` 设为不缓存（`Cache-Control: no-cache`）；模块包内容不可变，可以长期缓存。

## 6. 模块发布流程（游戏方）

宿主不需要做任何操作，以下由游戏方完成：

1. 用与目标 SDK 相同的主包构建 Android / iOS 平台的游戏 Bundle。
2. 把 Bundle 目录（根目录下有 `cc.config.json`）打成 zip。
3. 计算 zip 的 SHA-256 和大小，上传到清单所在站点。
4. 更新对应平台的 `catalog.json`：替换该 `gameId` + `sdkVersion` 的记录，`version` 比线上大。
5. 用 Demo 或测试包验证：第一次打开下载，第二次打开生效。

常见操作：

| 场景 | 做法 |
| --- | --- |
| 回滚到旧内容 | 用旧内容重新打包，以**更大的版本号**发布。版本号只能递增 |
| 停止下发某个版本 | 从清单删除该记录。已经安装的设备会继续使用已安装版本，直到有更大的版本 |
| 宿主升级了 SDK | 为新的 `sdkVersion` 单独发布模块；发布前宿主使用新 SDK 内置的模块 |
| 新版本有问题 | 已安装的设备加载失败会自动回退并标记坏版本；同时尽快发布修复版本 |

正式环境和 Demo 使用不同的清单，互不影响：

| 用途 | Android | iOS |
| --- | --- | --- |
| 正式 | `https://cocos-game-modules.pages.dev/android/catalog.json` | `https://cocos-game-modules.pages.dev/ios/catalog.json` |
| Demo | `https://cocos-game-modules.pages.dev/demo/android/catalog.json` | `https://cocos-game-modules.pages.dev/demo/ios/catalog.json` |

## 7. 运行 Demo

两个 Demo 都使用测试环境的游客会话打开牛牛，界面上有“检查更新”“游客打开游戏”两个按钮，以及当前的更新状态。

### 7.1 Android

环境：Android Studio，JDK 17，arm64 设备或模拟器。

```bash
cd android
./gradlew :app:installDebug
```

- SDK 版本默认 0.2.5，可用 `-PgameSdkVersion=x.y.z` 指定。
- 版本清单地址在 `app/build.gradle.kts` 的 `MODULE_CATALOG_URL`。
- 日志过滤：`adb logcat -s HotUpdateDemo GameModuleUpdater GameModuleStore`

### 7.2 iOS

环境：Xcode 16 及以上，iOS 16 及以上。

1. 打开 `ios/CocosGameHotUpdateDemo.xcodeproj`，Xcode 会通过 Swift Package Manager 拉取 `cocos-game-ios-sdk`。
2. 选择 `CocosGameHotUpdateDemo` scheme 运行。
3. 版本清单地址在 `CocosGameHotUpdateDemo/DemoConfig.h` 的 `DemoModuleCatalogURL`。

### 7.3 验证步骤

1. 首次安装后点“游客打开游戏”：使用内置模块，后台下载新版本，状态显示“新版本已安装，下次打开游戏生效”。
2. 关闭游戏，再次打开：牌桌顶部的倒计时文字前出现“热更新vN”字样，说明新模块已生效。
3. 再点“检查更新”：显示“已是最新版本”。

## 8. 常见问题

**Q：新版本下载完成后，能不能立即生效？**
不能。当前打开的游戏已经加载了旧模块，新版本统一在下次打开游戏时生效。

**Q：用户网络不好会不会打不开游戏？**
不会。打开游戏只使用本机已有的模块，更新在后台进行，失败只回调 `onUpdateFailed` / `gameSDKDidFailUpdateGame`。

**Q：宿主升级 SDK 后，之前下载的模块会怎样？**
旧 SDK 版本的模块不再使用，SDK 改用新版本内置模块，并等待游戏方为新 SDK 版本发布模块。

**Q：会不会占用很多存储？**
每个游戏只保留当前使用的一个版本，旧版本在下次打开游戏时自动删除。
