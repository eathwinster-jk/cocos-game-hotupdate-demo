// 热更新 Demo 宿主应用入口：初始化 SDK 并配置 Demo 专用版本清单。
#import "AppDelegate.h"

#import <CocosGameSDK/CocosGameSDK.h>

#import "DemoConfig.h"
#import "HotUpdateViewController.h"

@implementation AppDelegate

/**
 * 创建宿主窗口，初始化 SDK 并开启游戏模块热更新。
 */
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[HotUpdateViewController alloc] init];
    [[CocosGameSDK shared] initializeWithWindow:self.window launchOptions:launchOptions];
    [[CocosGameSDK shared] configure:[[CocosGameSDKConfig alloc] initWithCatalogURL:[NSURL URLWithString:DemoModuleCatalogURL]]];
    [self.window makeKeyAndVisible];
    return YES;
}

/**
 * 根据 SDK 当前页面限制宿主界面方向。
 */
- (UIInterfaceOrientationMask)application:(UIApplication *)application
    supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return CocosGameSDK.shared.preferredOrientationMask;
}

@end
