// 热更新 Demo 主页面：检查更新、展示更新进度，并把游戏以游客身份内嵌在页面顶部。
#import "HotUpdateViewController.h"

#import <CocosGameSDK/CocosGameSDK.h>
#import <CocosGameSDK/CocosGameSessionConfig.h>

#import "DemoConfig.h"

static NSString *const DemoUpdateStateChecking = @"checking";
static NSString *const DemoUpdateStateDownloading = @"downloading";
static NSString *const DemoUpdateStateInstalled = @"installed";
static NSString *const DemoUpdateStateUpToDate = @"upToDate";
static const CGFloat DemoGameAspectRatio = 211.0 / 375.0;
static const NSUInteger DemoBytesPerKilobyte = 1024;

@interface HotUpdateViewController () <CocosGameSDKDelegate>

@property(nonatomic, strong) UIView *gameContainer;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UILabel *messageLabel;
@property(nonatomic, strong) UIButton *openButton;
@property(nonatomic, strong) UIButton *closeButton;

@end

@implementation HotUpdateViewController

/**
 * 创建页面并接收 SDK 回调（包括更新进度）。
 */
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    CocosGameSDK.shared.delegate = self;
    [self buildInterface];
    [self updateGameButtons:NO];
}

/**
 * Demo 宿主页面仅支持竖屏，旋转全屏由 SDK 处理。
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

/**
 * 创建游戏容器与操作区。
 */
- (void)buildInterface {
    self.gameContainer = [[UIView alloc] init];
    self.gameContainer.backgroundColor = UIColor.blackColor;
    self.gameContainer.clipsToBounds = YES;
    self.gameContainer.translatesAutoresizingMaskIntoConstraints = NO;
    UIStackView *stack = [self createControlStack];
    [self.view addSubview:self.gameContainer];
    [self.view addSubview:stack];
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.gameContainer.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [self.gameContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.gameContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.gameContainer.heightAnchor constraintEqualToAnchor:self.gameContainer.widthAnchor multiplier:DemoGameAspectRatio],
        [stack.topAnchor constraintEqualToAnchor:self.gameContainer.bottomAnchor constant:16],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
    ]];
}

/**
 * 创建标题、清单地址、更新状态、操作按钮与说明。
 */
- (UIStackView *)createControlStack {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:[self createLabel:@"游戏模块热更新 Demo" size:24 color:UIColor.labelColor]];
    [stack addArrangedSubview:[self createLabel:[@"版本清单：" stringByAppendingString:DemoModuleCatalogURL] size:12 color:UIColor.secondaryLabelColor]];
    self.statusLabel = [self createLabel:@"更新状态：未检查" size:16 color:UIColor.labelColor];
    [stack addArrangedSubview:self.statusLabel];
    [stack addArrangedSubview:[self createButton:@"检查更新" action:@selector(checkUpdate)]];
    self.openButton = [self createButton:@"游客打开游戏" action:@selector(openGuestGame)];
    [stack addArrangedSubview:self.openButton];
    self.closeButton = [self createButton:@"关闭游戏" action:@selector(closeGame)];
    [stack addArrangedSubview:self.closeButton];
    [stack addArrangedSubview:[self createLabel:@"打开游戏时使用已安装的最新版本，并在后台检查新版本；下载完成的新版本在下次打开游戏时生效。"
                                           size:13 color:UIColor.secondaryLabelColor]];
    self.messageLabel = [self createLabel:@"" size:13 color:UIColor.systemRedColor];
    [stack addArrangedSubview:self.messageLabel];
    return stack;
}

/**
 * 创建多行文字。
 */
- (UILabel *)createLabel:(NSString *)text size:(CGFloat)size color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont systemFontOfSize:size];
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

/**
 * 创建圆角按钮。
 */
- (UIButton *)createButton:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.backgroundColor = UIColor.systemTealColor;
    button.layer.cornerRadius = 10;
    button.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:46].active = YES;
    return button;
}

/**
 * 根据游戏是否打开切换按钮可用状态。
 */
- (void)updateGameButtons:(BOOL)isGameOpen {
    self.openButton.enabled = !isGameOpen;
    self.openButton.alpha = isGameOpen ? 0.5 : 1;
    self.closeButton.enabled = isGameOpen;
    self.closeButton.alpha = isGameOpen ? 1 : 0.5;
}

/**
 * 预先检查并下载新版本，下次打开游戏生效。
 */
- (void)checkUpdate {
    [[CocosGameSDK shared] checkGameUpdate:DemoGameId];
}

/**
 * 以游客身份打开直播间牌桌；SDK 使用已安装的最新模块，并在后台检查新版本。
 */
- (void)openGuestGame {
    NSError *error = nil;
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0.0";
    NSString *deviceId = [@"ios-" stringByAppendingString:UIDevice.currentDevice.identifierForVendor.UUIDString ?: NSUUID.UUID.UUIDString];
    CocosGameSessionConfig *session = [[CocosGameSessionConfig alloc]
        initGuestWithWebsocketURL:DemoGameWebsocketURL apiBaseURL:DemoGameAPIURL deviceId:deviceId
                          sceneId:DemoGuestSceneId tableId:0
                    clientVersion:version deviceType:@"iOS" error:&error];
    if (!session) {
        self.messageLabel.text = error.localizedDescription;
        return;
    }
    self.messageLabel.text = @"";
    [self.view layoutIfNeeded];
    [[CocosGameSDK shared] openGame:DemoGameId sessionConfig:session inContainer:self.gameContainer fromViewController:self];
    [self updateGameButtons:YES];
}

/**
 * 关闭游戏，再次打开时会使用期间安装的新版本。
 */
- (void)closeGame {
    [[CocosGameSDK shared] close];
    [self updateGameButtons:NO];
}

/**
 * 把更新状态转换为页面文案。
 */
- (NSString *)createProgressText:(NSString *)state receivedBytes:(NSUInteger)receivedBytes totalBytes:(NSUInteger)totalBytes {
    if ([state isEqualToString:DemoUpdateStateChecking]) return @"更新状态：检查中…";
    if ([state isEqualToString:DemoUpdateStateDownloading]) {
        return [NSString stringWithFormat:@"更新状态：下载中 %lu / %lu KB",
            (unsigned long)(receivedBytes / DemoBytesPerKilobyte), (unsigned long)(totalBytes / DemoBytesPerKilobyte)];
    }
    if ([state isEqualToString:DemoUpdateStateInstalled]) return @"更新状态：新版本已安装，下次打开游戏生效";
    if ([state isEqualToString:DemoUpdateStateUpToDate]) return @"更新状态：已是最新版本";
    return state;
}

#pragma mark - CocosGameSDKDelegate

/**
 * 更新进度：SDK 在主线程回调。
 */
- (void)gameSDKDidUpdateGame:(NSString *)gameId
                       state:(NSString *)state
               receivedBytes:(NSUInteger)receivedBytes
                  totalBytes:(NSUInteger)totalBytes {
    NSLog(@"HotUpdateDemo 更新进度 gameId=%@, state=%@, %lu/%lu", gameId, state, (unsigned long)receivedBytes, (unsigned long)totalBytes);
    self.statusLabel.text = [self createProgressText:state receivedBytes:receivedBytes totalBytes:totalBytes];
}

/**
 * 更新失败：不影响打开游戏，SDK 会继续使用已安装版本或内置版本。
 */
- (void)gameSDKDidFailUpdateGame:(NSString *)gameId code:(NSInteger)code message:(NSString *)message {
    NSLog(@"HotUpdateDemo 更新失败 gameId=%@, code=%ld, message=%@", gameId, (long)code, message);
    self.statusLabel.text = [NSString stringWithFormat:@"更新失败（错误码 %ld）：%@", (long)code, message];
}

/**
 * 牌桌返回箭头：关闭游戏。
 */
- (void)gameSDKDidRequestBack {
    [self closeGame];
}

/**
 * 大厅会话失效：关闭游戏并提示原因。
 */
- (void)gameSDKDidInvalidateSessionWithMessage:(NSString *)message {
    [self closeGame];
    self.messageLabel.text = [@"会话已失效：" stringByAppendingString:message ?: @""];
}

/**
 * 记录 SDK 状态变化。
 */
- (void)gameSDKDidChangeState:(CocosGameSDKState)state {
    NSLog(@"HotUpdateDemo SDK 状态=%ld", (long)state);
}

/**
 * 展示 SDK 错误。
 */
- (void)gameSDKDidFailWithError:(NSError *)error {
    self.messageLabel.text = error.localizedDescription;
}

/**
 * 游客不会入座，退出确认直接放行。
 */
- (void)gameSDKDidRequestExitWithCompletion:(void (^)(BOOL))completion {
    completion(YES);
}

/**
 * 游客始终处于观战状态，无需处理。
 */
- (void)gameSDKDidChangePlayingState:(BOOL)isPlaying {
}

@end
