// 热更新 Demo 测试环境配置，与 Android Demo 保持一致。
#pragma once

#import <Foundation/Foundation.h>

// Demo 专用版本清单，与正式宿主使用的清单互相独立。
static NSString *const DemoModuleCatalogURL = @"https://cocos-game-modules.pages.dev/demo/ios/catalog.json";
// 清单签名公钥（可公开），SDK 用它校验 catalog.json.sig。
static NSString *const DemoModuleCatalogPublicKey = @"MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAErTdV8F92qHswr8ysK3qdPAlCSlOGceiYNZu02CJbHkGYFCbrUg/+TNJDPQNt+nSyS6oM9KIkh7o3+t2DcsyQuA==";
static NSString *const DemoGameId = @"niuniu";
static NSString *const DemoGameWebsocketURL = @"wss://test.imnono.net/game-ws/ws";
static NSString *const DemoGameAPIURL = @"https://test.imnono.net/game-lobby";
static NSString *const DemoGuestSceneId = @"3947124";
