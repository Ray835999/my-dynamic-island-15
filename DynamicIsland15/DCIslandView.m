#import "DCIslandView.h"
#import <MediaPlayer/MediaPlayer.h>
#import <CoreTelephony/CTCallCenter.h>
#import <CoreTelephony/CTCall.h>

// 灵动岛尺寸常量（参考 iPhone 14 Pro 收起态）
static const CGFloat kIslandWidthCollapsed  = 125.0;
static const CGFloat kIslandHeightCollapsed = 37.0;
static const CGFloat kIslandWidthExpanded   = 340.0;
static const CGFloat kIslandHeightExpanded  = 80.0;
static const CGFloat kIslandCornerRadius    = 20.0;
// iPhone 6s 无刘海，状态栏 20pt，灵动岛放在状态栏正下方
static const CGFloat kTopInset              = 22.0;

@interface DCIslandView ()
@property (nonatomic, strong) UIView                                   *container;
@property (nonatomic, strong) UILabel                                  *titleLabel;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *activeScenes; // scene -> content
@property (nonatomic, strong) CTCallCenter                             *callCenter;
@property (nonatomic, strong) NSTimer                                  *notificationTimer;
@property (nonatomic, assign) DCScene  currentScene;
@property (nonatomic, assign) BOOL     expanded;
@end

@implementation DCIslandView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _activeScenes = [NSMutableDictionary dictionary];
        _currentScene = DCSceneIdle;
        [self setupView];
        [self startObservingMusic];
        [self startObservingCall];
        [self startObservingCharging];
    }
    return self;
}

- (void)setupView {
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = YES;
    self.clipsToBounds = NO;

    _container = [[UIView alloc] init];
    _container.backgroundColor = [UIColor blackColor];
    _container.layer.cornerRadius = kIslandCornerRadius;
    _container.layer.masksToBounds = YES;
    [self addSubview:_container];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.numberOfLines = 2;
    _titleLabel.alpha = 0;
    [_container addSubview:_titleLabel];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap)];
    [_container addGestureRecognizer:tap];

    [self applyLayoutForScene:DCSceneIdle animated:NO];
}

#pragma mark - 场景管理

- (void)presentScene:(DCScene)scene content:(NSString *)content {
    if (scene == DCSceneIdle) return;
    @synchronized(_activeScenes) {
        _activeScenes[@(scene)] = content ?: [self defaultContentForScene:scene];
    }
    // 通知场景定时自动收起
    if (scene == DCSceneNotification) {
        [self.notificationTimer invalidate];
        self.notificationTimer = [NSTimer scheduledTimerWithTimeInterval:kNotificationSceneDuration
                                                                   target:self
                                                                 selector:@selector(onNotificationTimeout)
                                                                 userInfo:nil
                                                                  repeats:NO];
    }
    [self recomputeSceneAnimated:YES];
}

- (void)dismissScene:(DCScene)scene {
    @synchronized(_activeScenes) {
        [_activeScenes removeObjectForKey:@(scene)];
    }
    if (scene == DCSceneNotification) {
        [self.notificationTimer invalidate];
        self.notificationTimer = nil;
    }
    [self recomputeSceneAnimated:YES];
}

- (void)onNotificationTimeout {
    [self dismissScene:DCSceneNotification];
}

// 根据优先级选出当前应当显示的场景
- (void)recomputeSceneAnimated:(BOOL)animated {
    DCScene best = DCSceneIdle;
    NSInteger bestPri = 0;
    @synchronized(_activeScenes) {
        for (NSNumber *key in _activeScenes) {
            DCScene s = (DCScene)key.integerValue;
            NSInteger p = DCScenePriority(s);
            if (p > bestPri) { bestPri = p; best = s; }
        }
    }
    if (best == _currentScene) return;
    _currentScene = best;
    [self applyLayoutForScene:best animated:animated];
}

- (NSString *)defaultContentForScene:(DCScene)scene {
    switch (scene) {
        case DCSceneCall:         return @"通话中";
        case DCSceneCharging:     return @"🔋 充电中";
        case DCSceneNotification: return @"新通知";
        case DCSceneMusic:        return @"🎵 播放中";
        case DCSceneIdle:         return @"";
    }
    return @"";
}

#pragma mark - 布局

- (void)applyLayoutForScene:(DCScene)scene animated:(BOOL)animated {
    if (scene == DCSceneIdle) {
        [self layoutCollapsedAnimated:animated];
        return;
    }
    NSString *text = _activeScenes[@(scene)] ?: [self defaultContentForScene:scene];
    [self layoutExpandedWithText:text animated:animated];
}

- (void)layoutCollapsedAnimated:(BOOL)animated {
    _expanded = NO;
    CGFloat w = kIslandWidthCollapsed, h = kIslandHeightCollapsed;
    void (^block)(void) = ^{
        self.container.frame = CGRectMake((self.bounds.size.width - w) / 2, kTopInset, w, h);
        self.titleLabel.alpha = 0;
    };
    if (animated) [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:block completion:nil];
    else block();
}

- (void)layoutExpandedWithText:(NSString *)text animated:(BOOL)animated {
    _expanded = YES;
    CGFloat w = kIslandWidthExpanded, h = kIslandHeightExpanded;
    void (^block)(void) = ^{
        self.container.frame = CGRectMake((self.bounds.size.width - w) / 2, kTopInset, w, h);
        self.titleLabel.text = text;
        self.titleLabel.frame = self.container.bounds;
        self.titleLabel.alpha = 1;
    };
    if (animated) [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:block completion:nil];
    else block();
}

- (void)onTap {
    if (_expanded) {
        // 展开态点击：若是通知则手动关掉，否则收起
        if (_currentScene == DCSceneNotification) {
            [self dismissScene:DCSceneNotification];
        } else {
            [self layoutCollapsedAnimated:YES];
            _currentScene = DCSceneIdle;
        }
    } else {
        // 收起态点击：若有活跃场景则重新展开
        [self recomputeSceneAnimated:YES];
    }
}

#pragma mark - 音乐监听

// 兼容：不同 SDK 对 MPNowPlayingInfoCenter 通知名的声明有差异，
// 同时监听它和 MPMusicPlayerController 的通知，并用字符串兜底。
static NSString *const kDCNowPlayingInfoDidChangeNotification = @"MPNowPlayingInfoCenterNowPlayingInfoDidChangeNotification";

- (void)startObservingMusic {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    // 1) 字符串兜底（iOS 15 运行时实际广播的通知名）
    [nc addObserver:self selector:@selector(onMusicChanged:) name:kDCNowPlayingInfoDidChangeNotification object:nil];
    // 2) 新版 SDK 保留的 MPMusicPlayerController 通知
    [nc addObserver:self selector:@selector(onMusicChanged:) name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(onMusicChanged:) name:MPMusicPlayerControllerPlaybackStateDidChangeNotification object:nil];
    // 让系统音乐播放器激活事件派发（某些设备上需要主动触发）
    [[MPMusicPlayerController systemMusicPlayer] beginGeneratingPlaybackNotifications];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self refreshMusicState];
    });
}

- (void)onMusicChanged:(NSNotification *)note { [self refreshMusicState]; }

- (void)refreshMusicState {
    NSDictionary *info = [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo;
    if (info.count == 0) {
        [self dismissScene:DCSceneMusic];
        return;
    }
    NSString *title  = info[MPMediaItemPropertyTitle]  ?: @"";
    NSString *artist = info[MPMediaItemPropertyArtist] ?: @"";
    NSString *text = artist.length
        ? [NSString stringWithFormat:@"🎵 %@\n%@", title, artist]
        : [NSString stringWithFormat:@"🎵 %@", title];
    [self presentScene:DCSceneMusic content:text];
}

#pragma mark - 通话监听（CoreTelephony）

- (void)startObservingCall {
    // CTCallCenter 在 iOS 10+ 已 deprecated，但越狱环境下 SpringBoard 常驻前台仍可工作。
    _callCenter = [[CTCallCenter alloc] init];
    __weak typeof(self) ws = self;
    _callCenter.callEventHandler = ^(CTCall *call) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *state = call.callState;
            if ([state isEqualToString:CTCallStateConnected] ||
                [state isEqualToString:CTCallStateDialing] ||
                [state isEqualToString:CTCallStateIncoming]) {
                [ws presentScene:DCSceneCall content:@"📞 通话中"];
            } else {
                // CTCallStateDisconnected
                [ws dismissScene:DCSceneCall];
            }
        });
    };
}

#pragma mark - 充电监听

- (void)startObservingCharging {
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onBatteryChanged:)
                                                 name:UIDeviceBatteryStateDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onBatteryChanged:)
                                                 name:UIDeviceBatteryLevelDidChangeNotification
                                               object:nil];
    [self onBatteryChanged:nil];
}

- (void)onBatteryChanged:(NSNotification *)note {
    UIDeviceBatteryState st = [UIDevice currentDevice].batteryState;
    if (st == UIDeviceBatteryStateCharging || st == UIDeviceBatteryStateFull) {
        NSInteger level = (NSInteger)([UIDevice currentDevice].batteryLevel * 100);
        // 充电满则不再显示充电中，避免长驻
        if (st == UIDeviceBatteryStateFull) {
            [self dismissScene:DCSceneCharging];
            return;
        }
        [self presentScene:DCSceneCharging content:[NSString stringWithFormat:@"🔋 充电中 %ld%%", (long)level]];
    } else {
        [self dismissScene:DCSceneCharging];
    }
}

#pragma mark - 挂载到窗口

- (void)showOnWindow {
    UIWindow *host = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.windowLevel == UIWindowLevelNormal && !w.hidden) { host = w; break; }
    }
    if (!host) host = [UIApplication sharedApplication].keyWindow;
    if (!host) return;

    CGRect screen = host.bounds;
    self.frame = CGRectMake(0, 0, screen.size.width, kIslandHeightExpanded + kTopInset + 10);
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [host addSubview:self];
    [self applyLayoutForScene:DCSceneIdle animated:NO];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.notificationTimer invalidate];
}

@end
