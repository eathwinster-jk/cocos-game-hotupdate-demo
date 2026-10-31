// 热更新 Demo 测试环境配置，与 Android Demo 保持一致。
#pragma once

#import <Foundation/Foundation.h>

// Demo 专用版本清单，与正式宿主使用的清单互相独立。
static NSString *const DemoModuleCatalogURL = @"https://cocos-game-modules.pages.dev/demo/ios/catalog.json";
static NSString *const DemoGameId = @"niuniu";
static NSString *const DemoGameWebsocketURL = @"wss://test.imnono.net/game-ws/ws";
static NSString *const DemoGameAPIURL = @"https://test.imnono.net/game-lobby";
static NSString *const DemoGuestSceneId = @"3947124";
