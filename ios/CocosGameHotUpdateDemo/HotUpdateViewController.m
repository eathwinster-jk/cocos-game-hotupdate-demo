// 热更新 Demo 主页面：点击打开游戏时先检查并下载新版本、展示进度，完成后以游客身份把游戏内嵌在页面顶部，并在下方显示模块版本。
#import "HotUpdateViewController.h"

#import <CocosGameHotUpdate/CocosGameHotUpdate.h>
#import <CocosGameSDK/CocosGameSDK.h>

#import "DemoConfig.h"

static const CGFloat DemoGameAspectRatio = 211.0 / 375.0;
static const NSUInteger DemoBytesPerKilobyte = 1024;

@interface HotUpdateViewController () <CocosGameSDKDelegate, CocosGameHotUpdateDelegate>

@property(nonatomic, strong) CocosGameHotUpdate *hotUpdate;
@property(nonatomic, strong) UIView *gameContainer;
@property(nonatomic, strong) UILabel *placeholderLabel;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UIProgressView *progressView;
@property(nonatomic, strong) UILabel *versionLabel;
@property(nonatomic, strong) UILabel *messageLabel;
@property(nonatomic, strong) UIButton *openButton;
@property(nonatomic, strong) UIButton *closeButton;
@property(nonatomic, assign) BOOL isPreparingGame;

@end

@implementation HotUpdateViewController

/**
 * 创建页面，开启热更新（须在打开游戏前），并接收 SDK 与热更新回调。
 */
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    CocosGameSDK.shared.delegate = self;
    self.hotUpdate = [CocosGameHotUpdate installWithCatalogURL:[NSURL URLWithString:DemoModuleCatalogURL]];
    self.hotUpdate.delegate = self;
    [self buildInterface];
    [self updateVersionLabel];
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
    self.gameContainer = [self createGameContainer];
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
 * 创建游戏容器；未打开游戏时显示提示，游戏视图打开后覆盖在提示之上。
 */
- (UIView *)createGameContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = UIColor.blackColor;
    container.clipsToBounds = YES;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    self.placeholderLabel = [self createLabel:@"点击「打开游戏」加载" size:15 color:UIColor.lightGrayColor];
    self.placeholderLabel.textAlignment = NSTextAlignmentCenter;
    self.placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.placeholderLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.placeholderLabel.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [self.placeholderLabel.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
    ]];
    return container;
}

/**
 * 创建标题、清单地址、更新状态、进度条、模块版本、操作按钮与说明。
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
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    [stack addArrangedSubview:self.progressView];
    self.versionLabel = [self createLabel:@"" size:16 color:UIColor.labelColor];
    [stack addArrangedSubview:self.versionLabel];
    self.openButton = [self createButton:@"打开游戏" action:@selector(prepareAndOpenGame)];
    [stack addArrangedSubview:self.openButton];
    self.closeButton = [self createButton:@"关闭游戏" action:@selector(closeGame)];
    [stack addArrangedSubview:self.closeButton];
    [stack addArrangedSubview:[self createLabel:@"打开游戏前先检查并下载新版本，完成后加载游戏；网络失败时直接使用已安装版本或内置版本。"
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
 * 根据游戏是否打开（或正在准备）切换按钮可用状态。
 */
- (void)updateGameButtons:(BOOL)isGameOpen {
    BOOL canOpen = !isGameOpen && !self.isPreparingGame;
    self.openButton.enabled = canOpen;
    self.openButton.alpha = canOpen ? 1 : 0.5;
    self.closeButton.enabled = isGameOpen;
    self.closeButton.alpha = isGameOpen ? 1 : 0.5;
}

/**
 * 显示下次打开会加载的模块版本。
 */
- (void)updateVersionLabel {
    NSInteger version = [self.hotUpdate installedVersionForGameId:DemoGameId];
    self.versionLabel.text = version > 0 ? [NSString stringWithFormat:@"模块版本：v%ld（热更新）", (long)version] : @"模块版本：内置";
}

/**
 * 先检查并下载新版本，结束（已安装、已是最新或失败）后再打开游戏。
 */
- (void)prepareAndOpenGame {
    self.isPreparingGame = YES;
    self.messageLabel.text = @"";
    self.progressView.progress = 0;
    [self updateGameButtons:NO];
    [self.hotUpdate checkForUpdateWithGameId:DemoGameId];
}

/**
 * 下载流程结束后打开游戏；只响应本页面发起的那一次准备。
 */
- (void)finishPreparingGame {
    if (!self.isPreparingGame) return;
    self.isPreparingGame = NO;
    [self openGuestGame];
}

/**
 * 以游客身份打开直播间牌桌，使用刚刚安装的最新模块。
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
        [self updateGameButtons:NO];
        return;
    }
    [self updateVersionLabel];
    [self.view layoutIfNeeded];
    [[CocosGameSDK shared] openGame:DemoGameId sessionConfig:session inContainer:self.gameContainer fromViewController:self];
    [self updateGameButtons:YES];
}

/**
 * 关闭游戏，回到空白游戏区。
 */
- (void)closeGame {
    [[CocosGameSDK shared] close];
    [self updateGameButtons:NO];
}

/**
 * 把更新状态转换为页面文案。
 */
- (NSString *)createProgressText:(NSString *)state receivedBytes:(NSUInteger)receivedBytes totalBytes:(NSUInteger)totalBytes {
    if ([state isEqualToString:CocosGameHotUpdateStateChecking]) return @"更新状态：检查中…";
    if ([state isEqualToString:CocosGameHotUpdateStateDownloading]) {
        return [NSString stringWithFormat:@"更新状态：下载中 %lu / %lu KB",
            (unsigned long)(receivedBytes / DemoBytesPerKilobyte), (unsigned long)(totalBytes / DemoBytesPerKilobyte)];
    }
    if ([state isEqualToString:CocosGameHotUpdateStateInstalled]) return @"更新状态：新版本已安装";
    if ([state isEqualToString:CocosGameHotUpdateStateUpToDate]) return @"更新状态：已是最新版本";
    return state;
}

#pragma mark - CocosGameHotUpdateDelegate

/**
 * 更新进度：热更新库在主线程回调；已安装或已是最新时结束准备并打开游戏。
 */
- (void)gameHotUpdateDidUpdateGame:(NSString *)gameId
                             state:(NSString *)state
                     receivedBytes:(NSUInteger)receivedBytes
                        totalBytes:(NSUInteger)totalBytes {
    NSLog(@"HotUpdateDemo 更新进度 gameId=%@, state=%@, %lu/%lu", gameId, state, (unsigned long)receivedBytes, (unsigned long)totalBytes);
    self.statusLabel.text = [self createProgressText:state receivedBytes:receivedBytes totalBytes:totalBytes];
    if (totalBytes > 0) self.progressView.progress = (float)receivedBytes / (float)totalBytes;
    if ([state isEqualToString:CocosGameHotUpdateStateInstalled] || [state isEqualToString:CocosGameHotUpdateStateUpToDate]) {
        self.progressView.progress = 1;
        [self finishPreparingGame];
    }
}

/**
 * 更新失败：不影响打开游戏，继续使用已安装版本或内置版本。
 */
- (void)gameHotUpdateDidFailUpdateGame:(NSString *)gameId code:(NSInteger)code message:(NSString *)message {
    NSLog(@"HotUpdateDemo 更新失败 gameId=%@, code=%ld, message=%@", gameId, (long)code, message);
    self.statusLabel.text = [NSString stringWithFormat:@"更新失败（错误码 %ld）：%@", (long)code, message];
    [self finishPreparingGame];
}

#pragma mark - CocosGameSDKDelegate

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
