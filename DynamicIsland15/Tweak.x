// DynamicIsland15 —— 在 iOS 15 上模拟灵动岛
// 原理：hook SpringBoard 的 SBIconController 挂载自定义药丸视图；
//       视图内置监听音乐/通话/充电，本文件额外 hook 通知横幅呈现，
//       把通知推入灵动岛作为短时场景。
// 注意：iOS 15 系统没有原生灵动岛组件，这是“画”出来的模拟物，不是激活原生功能。

#import "DCIslandView.h"

// 全局持有，避免被释放
static DCIslandView *sIsland = nil;

%hook SBIconController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sIsland = [[DCIslandView alloc] initWithFrame:CGRectZero];
        [sIsland showOnWindow];
    });
}

%end

// ---------------------------------------------------------------------------
// 通知场景：hook 通知横幅的呈现与消失。
// iOS 15 上横幅由 SBUserNotificationAlert 承载，
// 它在显示时调用 -activate / -alertDidAppear:，移除时调用 -deactivate / -alertWillDisappear:。
// 不同版本方法名可能有差异，这里用一组候选方法，运行时 Substrate 会按存在性匹配。
// 若通知不触发，可用 class-dump 核对方法名后调整下方 hook 名。
// ---------------------------------------------------------------------------

@interface SBUserNotificationAlert : NSObject
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *message;
@end

%hook SBUserNotificationAlert

// 横幅出现：推入通知场景
- (void)activate {
    %orig;
    NSString *title = self.title ?: @"";
    NSString *body  = self.message ?: @"";
    NSString *text = body.length
        ? [NSString stringWithFormat:@"🔔 %@\n%@", title, body]
        : [NSString stringWithFormat:@"🔔 %@", title];
    dispatch_async(dispatch_get_main_queue(), ^{
        [sIsland presentScene:DCSceneNotification content:text];
    });
}

- (void)deactivate {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        [sIsland dismissScene:DCSceneNotification];
    });
}

%end
