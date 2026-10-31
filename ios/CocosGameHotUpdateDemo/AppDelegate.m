// 热更新 Demo 宿主应用入口：初始化 SDK，热更新由主页面开启。
#import "AppDelegate.h"

#import <CocosGameSDK/CocosGameSDK.h>

#import "HotUpdateViewController.h"

@implementation AppDelegate

/**
 * 创建宿主窗口并初始化 SDK。
 */
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    [[CocosGameSDK shared] initializeWithWindow:self.window launchOptions:launchOptions];
    self.window.rootViewController = [[HotUpdateViewController alloc] init];
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
