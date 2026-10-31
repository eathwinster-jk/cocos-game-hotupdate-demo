# Cocos 游戏模块热更新接入文档

本仓库是游戏模块热更新的独立接入文档和 Demo，包含 Android 和 iOS 两个精简宿主，只演示热更新相关接口。游戏 SDK 的完整接入（登录会话、下注、记录等）请参考各平台 SDK 文档。

- Android Demo：[`android/`](android/)
- iOS Demo：[`ios/`](ios/)

## 1. 概述

游戏玩法以 Cocos Bundle（游戏模块）的形式内置在 SDK 中。开启热更新后，游戏方可以单独发布新的游戏模块，宿主无需升级 SDK、无需发版即可让用户用上新版本。

工作方式：

1. 宿主打开游戏时，SDK 使用本机已安装的最新模块；没有安装过就使用 SDK 内置的模块。
2. 同时在后台拉取版本清单，有新版本就下载、校验并安装。本机已有旧版本（或内置模块）时优先下载只含变化文件的增量补丁，补丁不可用时下载完整包；下载按分片进行，中断后从已完成的分片继续。
3. 新版本在**下次打开游戏**时生效，不会打断当前正在玩的游戏。
4. 宿主也可以在打开游戏前先检查并下载（见 3.4），下载完成后再打开，首次打开就使用新版本。

适用平台：Android、iOS。H5 SDK 每次都从网页加载最新资源，不需要热更新。

## 2. 依赖

从 0.3.0 起，热更新是独立的库，与游戏 SDK 同版本发布，宿主按需引入。不引入热更新库时，SDK 始终使用内置模块。

| 平台 | 热更新库 |
| --- | --- |
| Android | `com.eath.cocosgamesdk:game-sdk-hotupdate:0.5.0`（自动带上同版本 `game-sdk`） |
| iOS SPM | `https://github.com/eathwinster-jk/cocos-game-ios-sdk` 0.5.0，勾选 `CocosGameHotUpdate` 产品（已包含 `CocosGameSDK`） |
| iOS CocoaPods | `pod 'CocosGameHotUpdate', :podspec => 'https://raw.githubusercontent.com/eathwinster-jk/cocos-game-ios-sdk/0.5.0/CocosGameHotUpdate.podspec'`，同时保留 `CocosGameSDK` 的 pod |

热更新库与游戏 SDK 的版本必须一致。查询已安装版本的接口从 0.3.1 起提供；清除、取消接口与失败重试从 0.3.2 起提供；清单签名、灰度发布、远程回滚、埋点事件、增量更新、分片下载和断点续传从 0.5.0 起提供。

游戏模块依赖 SDK 内置的主包脚本，**只适用于构建它的那个 SDK 版本**。宿主升级 SDK 后，SDK 只会安装为新 SDK 版本发布的模块；在游戏方发布之前，使用新 SDK 内置的模块。

### 从 0.2.5 升级

| 平台 | 0.2.5 | 0.3.0 |
| --- | --- | --- |
| Android | `initialize(context, new GameSDKConfig(url))` | `initialize(context)` + `GameHotUpdate.install(context, url)` |
| Android | `CocosGameSDK.setUpdateListener` / `checkGameUpdate` | `GameHotUpdate.setUpdateListener` / `checkForUpdate` |
| iOS | `configure:[[CocosGameSDKConfig alloc] initWithCatalogURL:url]` | `[CocosGameHotUpdate installWithCatalogURL:url]` |
| iOS | `CocosGameSDKDelegate` 的 `gameSDKDidUpdateGame…` / `gameSDKDidFailUpdateGame…` | `CocosGameHotUpdateDelegate` 的 `gameHotUpdateDidUpdateGame…` / `gameHotUpdateDidFailUpdateGame…` |
| iOS | `checkGameUpdate:` | `checkForUpdateWithGameId:` |

## 3. 宿主接入

初始化 SDK 后、打开游戏前，用版本清单地址开启热更新即可。

版本清单地址由游戏方提供，必须是 HTTPS，并且 Android、iOS 各用一份。

### 3.1 Android

```java
CocosGameSDK.getInstance().initialize(context);
// 第三个参数是清单签名公钥（0.5.0 起），由游戏方提供
GameHotUpdate hotUpdate = GameHotUpdate.install(context,
        "https://<清单域名>/android/catalog.json", "<清单签名公钥>");

// 可选：监听更新进度，回调在主线程
hotUpdate.setUpdateListener(new GameUpdateListener() {
    @Override
    public void onUpdateProgress(String gameId, String state, long receivedBytes, long totalBytes) {
        Log.i("Host", "更新进度 " + gameId + " " + state + " " + receivedBytes + "/" + totalBytes);
    }

    @Override
    public void onUpdateFailed(String gameId, int code, String message) {
        Log.w("Host", "更新失败 " + gameId + " code=" + code + " " + message);
    }

    // 0.5.0 起：埋点事件，宿主上报到自己的统计平台
    @Override
    public void onUpdateEvent(GameUpdateEvent event) {
        Log.i("Host", "埋点 " + event.getName() + " version=" + event.getVersion());
    }
});

// 可选：在打开游戏之前预先下载，例如进入直播间时
hotUpdate.checkForUpdate("niuniu");

// 查询下次打开会使用的模块版本，0 表示 SDK 内置模块
int version = hotUpdate.getInstalledVersion("niuniu");

// 0.3.2 起：取消进行中的检查或下载（结束时回调错误码 5）
hotUpdate.cancelUpdate("niuniu");

// 0.3.2 起：关闭游戏后清除已下载的模块，下次打开回到内置模块并重新下载；
// 游戏打开中或正在下载时返回 false
boolean isCleared = hotUpdate.clearInstalledModules("niuniu");
```

页面销毁时调用 `setUpdateListener(null)`，避免监听器持有已销毁的页面。状态和错误码常量见 `GameHotUpdate.STATE_*`、`GameHotUpdate.ERROR_*`。

### 3.2 iOS

```objc
#import <CocosGameHotUpdate/CocosGameHotUpdate.h>

[[CocosGameSDK shared] initializeWithWindow:self.window launchOptions:launchOptions];
NSURL *catalogURL = [NSURL URLWithString:@"https://<清单域名>/ios/catalog.json"];
// 宿主需要持有返回的对象，作为 delegate 的生命周期依据；
// 第二个参数是清单签名公钥（0.5.0 起），公钥格式错误时返回 nil
self.hotUpdate = [CocosGameHotUpdate installWithCatalogURL:catalogURL
                                          catalogPublicKey:@"<清单签名公钥>"];
self.hotUpdate.delegate = self;

// 可选：在打开游戏之前预先下载
[self.hotUpdate checkForUpdateWithGameId:@"niuniu"];

// 查询下次打开会使用的模块版本，0 表示 SDK 内置模块
NSInteger version = [self.hotUpdate installedVersionForGameId:@"niuniu"];

// 0.3.2 起：取消进行中的检查或下载（结束时回调错误码 5）
[self.hotUpdate cancelUpdateWithGameId:@"niuniu"];

// 0.3.2 起：关闭游戏后清除已下载的模块，游戏打开中或正在下载时返回 NO
BOOL isCleared = [self.hotUpdate clearInstalledModulesForGameId:@"niuniu"];
```

更新进度通过 `CocosGameHotUpdateDelegate` 的可选方法回调，均在主线程：

```objc
- (void)gameHotUpdateDidUpdateGame:(NSString *)gameId
                             state:(NSString *)state
                     receivedBytes:(NSUInteger)receivedBytes
                        totalBytes:(NSUInteger)totalBytes {
    NSLog(@"更新进度 %@ %@ %lu/%lu", gameId, state, (unsigned long)receivedBytes, (unsigned long)totalBytes);
}

- (void)gameHotUpdateDidFailUpdateGame:(NSString *)gameId code:(NSInteger)code message:(NSString *)message {
    NSLog(@"更新失败 %@ code=%ld %@", gameId, (long)code, message);
}

// 0.5.0 起：埋点事件
- (void)gameHotUpdateDidRecordEvent:(CocosGameHotUpdateEvent *)event {
    NSLog(@"埋点 %@ version=%ld", event.name, (long)event.version);
}
```

状态常量见 `CocosGameHotUpdateState*`，错误码见 `CocosGameHotUpdateErrorCode`，事件名见 `CocosGameHotUpdateEvent*`。

清单签名公钥是 Base64 格式的 ECDSA P-256 公钥（X.509 SubjectPublicKeyInfo），可以公开，直接写在宿主代码或配置里。传入公钥后，SDK 只信任签名正确的版本清单；不传公钥（Android 两个参数的 `install`、iOS 的 `installWithCatalogURL:`）时不校验签名，只建议在调试时使用。

### 3.3 回调说明

更新进度的 `state` 取值：

| state | 含义 | receivedBytes / totalBytes |
| --- | --- | --- |
| `checking` | 正在拉取版本清单 | 0 / 0 |
| `downloading` | 正在下载模块包 | 已下载 / 总大小（字节）；增量更新时为补丁大小，补丁失败改下完整包后为完整包大小 |
| `installed` | 新版本已安装，下次打开游戏生效 | 总大小 / 总大小 |
| `upToDate` | 没有可安装的新版本 | 0 / 0 |

失败回调的错误码：

| code | 含义 |
| --- | --- |
| 1 | 网络错误：清单或模块包下载失败、HTTP 状态码非 200（已自动重试后仍失败） |
| 2 | 版本清单格式错误 |
| 3 | 模块包校验失败：大小或 SHA-256 与清单不一致（补丁失败会先自动改下完整包，完整包仍失败才回调） |
| 4 | 安装失败：解压或写入失败（同上，补丁失败会先改下完整包） |
| 5 | 已取消：宿主调用了取消接口（0.3.2 起） |
| 6 | 存储空间不足：可用空间小于模块包大小的 4 倍（0.3.2 起） |
| 7 | 版本清单签名校验失败：签名文件缺失、被篡改或公钥不匹配（0.5.0 起） |

**更新失败不会影响打开游戏**，SDK 会继续使用已安装的版本或内置版本。宿主一般只需要记录日志，不需要提示用户。

埋点事件（0.5.0 起）：Android `GameUpdateListener.onUpdateEvent`，iOS `gameHotUpdateDidRecordEvent:`，均在主线程。事件包含 `gameId`、`name`、`version`、`bytes`、`durationMs`、`retryCount`、`errorCode`、`message`，未涉及的字段为 0 或空。0.5.0 起下载、安装相关事件还带 `updateType`（`full` 完整包 / `patch` 增量补丁）和 `baseVersion`（补丁基于的本机版本，0 为内置模块，-1 表示完整包或不涉及）。

| name | 时机 | 有效字段 |
| --- | --- | --- |
| `checkStarted` | 开始检查更新 | — |
| `rolloutSkipped` | 最新版本的灰度未覆盖本机 | `version`：最新版本 |
| `rolledBack` | 本机已安装的版本被游戏方回滚，退回内置模块 | `version`：被回滚的版本 |
| `downloadStarted` | 开始下载模块包 | `version`、`bytes`、`updateType`、`baseVersion` |
| `downloadSucceeded` | 下载并校验成功 | `version`、`bytes`、`durationMs`（下载耗时）、`retryCount`、`updateType`、`baseVersion` |
| `patchFallback` | 增量补丁校验或安装失败，改下完整包（0.5.0 起） | `version`、`baseVersion`、`message`（失败原因） |
| `installSucceeded` | 安装完成 | `version`、`bytes`、`durationMs`（从开始检查算起）、`retryCount`、`updateType`、`baseVersion` |
| `updateFailed` | 更新失败，与失败回调同时发生 | `errorCode`、`message`、`version`、`durationMs`、`retryCount` |
| `launchFailed` | 新版本加载失败，已标记为坏版本 | `version`、`message` |

`retryCount` 是本次更新中网络重试的总次数。可以用 `downloadSucceeded` 的耗时和重试次数监控下载质量，用 `updateType` 统计增量更新的比例，用 `patchFallback` 发现本机文件被改动或补丁有问题，用 `launchFailed` 监控新版本是否有问题。

断点续传时 `bytes` 仍是整个包的大小，不是本次实际下载的字节数。

### 3.4 宿主需要注意的事项

- 开启热更新要在打开游戏之前；打开游戏时会自动检查更新，`checkForUpdate` 只是提前下载，不调用也可以。
- 想让首次打开就用上新版本：先调用 `checkForUpdate`，在回调 `installed`、`upToDate` 或失败后再打开游戏（Demo 即为此做法）。下载期间可以用 `downloading` 回调的字节数显示进度。网络慢时会延后打开游戏，宿主可按需设置等待上限，超时直接打开。
- 热更新只需开启一次，重复开启以最后一次为准。
- 同一个游戏同时只会有一个下载任务，重复调用会被忽略。
- 模块存放位置由 SDK 管理，宿主不要直接删除或修改，需要清理时调用清除接口：
  - Android：`Context.getFilesDir()/cocos_game_modules/`
  - iOS：`Documents/cocos_game_modules/`（已排除 iCloud 备份）
- 清除接口会同时清掉坏版本记录，适合"清理缓存"或排查问题后重新热更；必须在关闭游戏后调用。
- 宿主如果在清理缓存时直接删除了上述目录，SDK 会退回内置模块，下次打开游戏时重新下载。

## 4. 安全与容错机制

| 机制 | 说明 |
| --- | --- |
| 仅 HTTPS | 清单地址和模块包地址都必须是 HTTPS |
| 清单签名 | 游戏方用私钥对 `catalog.json` 签名，SDK 用宿主传入的公钥校验，防止清单被篡改或替换（0.5.0 起） |
| 完整性校验 | manifest、每个分片、整个包都校验大小和 SHA-256；0.5.0 起安装前再逐个文件校验，不一致则丢弃 |
| 大小限制 | 单个模块包不超过 64 MB，manifest 不超过 4 MB |
| 安全解压 | 拒绝写到模块目录以外的路径 |
| 原子安装 | 先解压到临时目录，校验通过后再切换为正式版本，中途失败不影响已安装版本 |
| 失败重试 | 连接失败、读取中断、HTTP 5xx / 408 / 429 自动重试 3 次，间隔 1、2、4 秒；其他状态码和校验失败不重试（0.3.2 起） |
| 增量更新 | 本机版本（或内置模块）在 manifest 的补丁列表中时只下载变化的文件，其余从本机复制（0.5.0 起） |
| 补丁回退 | 补丁校验或安装失败（例如本机文件被改动）时自动改下完整包，并上报 `patchFallback`（0.5.0 起） |
| 断点续传 | 包按约 1 MB 分片下载，校验通过的分片缓存在本机；中断、杀进程后下次更新只下载剩余分片（0.5.0 起） |
| 临时文件清理 | 每次更新开始前删除上次中断留下的临时目录；分片缓存只保留目标版本的，安装成功后删除（0.3.2 起，0.5.0 调整） |
| 空间检查 | 下载前确认可用空间不少于模块包大小的 4 倍，不足时不下载（0.3.2 起） |
| 加载失败回退 | 新版本加载失败时，本次立即改用内置模块，并把该版本标记为坏版本，以后不再安装 |
| 启动确认 | 新版本连续 2 次打开都没有成功进入游戏，自动标记为坏版本，退回内置模块 |
| SDK 升级重置 | SDK 版本变化后，旧版本的模块和坏版本记录全部失效 |
| 灰度发布 | 按比例下发新版本，灰度外的设备使用上一个版本（0.5.0 起） |
| 远程回滚 | 游戏方拉黑有问题的版本，已安装的设备自动退回并安装旧版本（0.5.0 起） |

## 5. 版本清单格式

每个平台一份 `catalog.json`，旁边放签名文件 `catalog.json.sig`：

```json
{
  "schemaVersion": 1,
  "modules": [
    {
      "gameId": "niuniu",
      "sdkVersion": "0.5.0",
      "version": 3,
      "url": "niuniu/0.5.0/3.zip",
      "sha256": "e2945ba2c23186442aaffdaf42e358b9baabe981373d7c595317b3f543ef693f",
      "size": 1818897,
      "manifest": {
        "url": "niuniu/0.5.0/3/manifest.json",
        "sha256": "4055654002ff8b2be1f370b0c91d577828de25712422d221355be0181ba4b760",
        "size": 29227
      },
      "rolloutPercent": 20,
      "blockedVersions": [],
      "previous": [
        {
          "version": 2,
          "url": "niuniu/0.5.0/2.zip",
          "sha256": "96045d188b82ced0fea06d283ddd3fcb2b1da4471041b56ff39a514d8175fe85",
          "size": 1818897,
          "manifest": {
            "url": "niuniu/0.5.0/2/manifest.json",
            "sha256": "220725c63620fef31688f257f44383acbf395ddae16ef342cc8e302a9fd6b334",
            "size": 28894
          }
        }
      ]
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
| `manifest` | 对象，可选 | 该版本的文件清单 `manifest.json`：`url`（相对清单地址解析）、`sha256`、`size`（不超过 4 MB）。有它时 0.5.0 起的 SDK 走增量更新和分片下载，没有时下载 `url` 指向的完整 zip（0.5.0 起） |
| `rolloutPercent` | 整数，可选 | 最新版本的灰度比例 0–100，默认 100（0.5.0 起） |
| `blockedVersions` | 整数数组，可选 | 已回滚的版本，设备上装了这些版本会退回内置模块，也不会再安装（0.5.0 起） |
| `previous` | 数组，可选 | 之前的版本，按版本从新到旧，最多 3 个，字段同 `version`/`url`/`sha256`/`size`/`manifest`；灰度外的设备安装其中最新、未被回滚的版本（0.5.0 起） |

同一个 `gameId` + `sdkVersion` 只保留一条记录。SDK 先选出本机可用的版本（灰度内取 `version`，灰度外取 `previous` 中最新的未回滚版本），只在它大于本机已安装版本、且不是坏版本时才安装。旧版本 SDK 会忽略新增字段。

灰度分桶：SDK 首次运行时在模块目录生成一个随机 ID（不采集任何设备标识），对 `随机 ID:gameId:version` 取 SHA-256，前 4 个字节按无符号大端整数对 100 取余，小于 `rolloutPercent` 即在灰度内。同一设备同一版本的结果固定，调大比例时已覆盖的设备不会被移出；卸载重装或清除应用数据后会重新分桶。

签名文件：`catalog.json.sig` 是对 `catalog.json` 原始字节做 ECDSA P-256 / SHA-256 签名（DER 编码）后的 Base64 文本。修改清单后必须重新签名，否则开启了签名校验的宿主会报错误码 7。

缓存建议：`catalog.json` 和 `catalog.json.sig` 设为不缓存（`Cache-Control: no-cache`）；模块包、`manifest.json` 和分片内容不可变，可以长期缓存。

### 5.1 文件清单 manifest.json（0.5.0 起）

每个版本一份，放在 `{gameId}/{sdkVersion}/{version}/manifest.json`，分片地址相对 manifest 所在目录解析：

```json
{
  "schemaVersion": 1,
  "gameId": "niuniu",
  "sdkVersion": "0.5.0",
  "version": 3,
  "files": [
    { "path": "cc.config.json", "sha256": "ba98…2e4f", "size": 6760 },
    { "path": "hotupdate_test/v3.txt", "sha256": "3669…705a", "size": 10 }
  ],
  "full": {
    "sha256": "e294…693f",
    "size": 1818897,
    "chunks": [
      { "url": "full/0.bin", "sha256": "b32e…e566", "size": 1048576 },
      { "url": "full/1.bin", "sha256": "a5fd…cb5f", "size": 770321 }
    ]
  },
  "patches": [
    {
      "fromVersion": 2,
      "sha256": "3029…2b6f",
      "size": 48645,
      "chunks": [{ "url": "from-2/0.bin", "sha256": "3029…2b6f", "size": 48645 }]
    }
  ]
}
```

| 字段 | 说明 |
| --- | --- |
| `gameId` / `sdkVersion` / `version` | 必须与版本清单中的记录一致 |
| `files` | 该版本的完整文件列表（相对 Bundle 根目录的路径、SHA-256、大小）。安装前逐个校验，不在列表中的文件不会出现在新版本里 |
| `full` | 完整包：zip 的 SHA-256、大小，以及按顺序拼接成 zip 的分片列表；分片大小之和必须等于 `size` |
| `patches` | 增量补丁，可选，字段同 `full` 外加 `fromVersion`（基于的版本，0 为 SDK 内置模块）。补丁 zip 只包含新增和修改的文件，删除的文件由 `files` 体现 |

SDK 的选择规则：本机已安装版本（没有则为内置模块 0）在 `patches` 中就下载补丁，解压后从本机版本复制其余文件；否则下载 `full`。补丁校验或安装失败时改下 `full`。

## 6. 模块发布流程（游戏方）

宿主不需要做任何操作，以下由游戏方完成：

1. 用与目标 SDK 相同的主包构建 Android / iOS 平台的游戏 Bundle。
2. 把 Bundle 目录（根目录下有 `cc.config.json`）打成 zip。
3. 计算 zip 的 SHA-256 和大小，上传到清单所在站点。
4. 生成该版本的 `manifest.json`、完整包分片，以及基于最近 3 个旧版本和 SDK 内置模块的补丁分片（只保留比完整包小的补丁），一起上传（0.5.0 起，发布脚本自动完成）。
5. 更新对应平台的 `catalog.json`：替换该 `gameId` + `sdkVersion` 的记录，`version` 比线上大，填上 `manifest`，原来的版本移到 `previous`。
6. 用私钥重新生成 `catalog.json.sig`，与清单一起上传。
7. 用 Demo 或测试包验证：第一次打开下载，第二次打开生效。

常见操作：

| 场景 | 做法 |
| --- | --- |
| 灰度发布 | 新版本先设较小的 `rolloutPercent`，观察埋点后逐步调大到 100 |
| 回滚 | 把有问题的版本加入 `blockedVersions`，记录改回 `previous` 中的上一个版本。已安装问题版本的设备下次检查时退回内置模块，再下载上一个版本 |
| 停止下发某个版本 | 同回滚。0.5.0 之前的 SDK 不认识 `blockedVersions`，只能用旧内容以**更大的版本号**重新发布 |
| 宿主升级了 SDK | 为新的 `sdkVersion` 单独发布模块；发布前宿主使用新 SDK 内置的模块 |
| 新版本有问题 | 已安装的设备加载失败会自动回退并标记坏版本；同时尽快发布修复版本 |

正式环境和 Demo 使用不同的清单，互不影响：

| 用途 | Android | iOS |
| --- | --- | --- |
| 正式 | `https://cocos-game-modules.pages.dev/android/catalog.json` | `https://cocos-game-modules.pages.dev/ios/catalog.json` |
| Demo | `https://cocos-game-modules.pages.dev/demo/android/catalog.json` | `https://cocos-game-modules.pages.dev/demo/ios/catalog.json` |

## 7. 运行 Demo

两个 Demo 都使用测试环境的游客会话，把牛牛牌桌嵌在页面顶部。启动时游戏区为空；点“打开游戏”后先检查并下载新版本，下方显示进度，完成后加载游戏，并在下方显示当前加载的模块版本。

### 7.1 Android

环境：Android Studio，JDK 17，arm64 设备或模拟器。

```bash
cd android
./gradlew :app:installDebug
```

- SDK 版本默认 0.5.0，可用 `-PgameSdkVersion=x.y.z` 指定（不低于 0.5.0）。
- 版本清单地址和签名公钥在 `app/build.gradle.kts` 的 `MODULE_CATALOG_URL`、`MODULE_CATALOG_PUBLIC_KEY`，公钥也可以用 `-PmoduleCatalogPublicKey=...` 覆盖。
- 日志过滤：`adb logcat -s HotUpdateDemo GameModuleUpdater GameModuleStore`

### 7.2 iOS

环境：Xcode 16 及以上，iOS 16 及以上。

1. 打开 `ios/CocosGameHotUpdateDemo.xcodeproj`，Xcode 会通过 Swift Package Manager 拉取 `cocos-game-ios-sdk` 的 `CocosGameHotUpdate` 产品。
2. 选择 `CocosGameHotUpdateDemo` scheme 运行。
3. 版本清单地址和签名公钥在 `CocosGameHotUpdateDemo/DemoConfig.h` 的 `DemoModuleCatalogURL`、`DemoModuleCatalogPublicKey`。

### 7.3 验证步骤

1. 首次安装后，下方显示“模块版本：内置”，游戏区为空。
2. 点“打开游戏”：状态依次显示“检查中”“下载中 x / y KB”和进度条，下载完成后加载牌桌，下方显示“模块版本：vN（热更新）”。
3. 点“关闭游戏”再打开：状态显示“已是最新版本”，直接加载同一版本。
4. Android：关闭游戏后点“清除热更新”，下方变为“模块版本：内置”；再点“打开游戏”会重新下载并加载新版本。游戏打开或下载中该按钮不可用。
5. 日志中以“埋点”开头的行即埋点事件，可以看到 `checkStarted`、`downloadStarted` 到 `installSucceeded` 的完整过程；`updateType=patch` 表示走了增量补丁，`baseVersion` 为补丁基于的本机版本。
6. 断点续传：下载过程中杀掉 App 再打开，日志会出现“继续下载，已缓存 x/y 字节”，只下载剩余分片。

## 8. 常见问题

**Q：新版本下载完成后，能不能立即生效？**
不能。当前打开的游戏已经加载了旧模块，新版本统一在下次打开游戏时生效。

**Q：用户网络不好会不会打不开游戏？**
不会。打开游戏只使用本机已有的模块，更新在后台进行，失败只回调 `onUpdateFailed` / `gameHotUpdateDidFailUpdateGame`。

**Q：宿主升级 SDK 后，之前下载的模块会怎样？**
旧 SDK 版本的模块不再使用，SDK 改用新版本内置模块，并等待游戏方为新 SDK 版本发布模块。

**Q：签名公钥泄露了有风险吗？**
没有。公钥只能用来校验，不能伪造签名。私钥只保存在游戏方的发布机上，不会进入 SDK、Demo 或任何仓库。

**Q：灰度外的用户会怎样？**
安装 `previous` 中最新的未回滚版本；如果没有，就继续使用已安装的版本或内置模块。

**Q：会不会占用很多存储？**
每个游戏只保留当前使用的一个版本，旧版本在下次打开游戏时自动删除。未完成下载的分片缓存只保留正在更新的那个版本，安装成功后删除。

**Q：增量更新能省多少流量？**
取决于改动的文件。只改了脚本时，补丁通常只有几十 KB，完整包约 1.8 MB。补丁覆盖最近 3 个旧版本和 SDK 内置模块，更老的版本或补丁不比完整包小时下载完整包。

**Q：用户本机的模块文件被改动了会怎样？**
补丁安装前会逐个文件校验，不一致时上报 `patchFallback` 并自动下载完整包，不会装出损坏的版本。
