#import <UIKit/UIKit.h>
#import "DCIslandScene.h"

// 模拟灵动岛视图：挂到 SpringBoard 主窗口顶部，药丸形态，
// 内置监听音乐 / 通话 / 充电，外部可调用 presentScene 推入通知等场景。
@interface DCIslandView : UIView

// 挂到 SpringBoard 主窗口
- (void)showOnWindow;

// 外部 hook 调用：呈现/取消某个场景。
// content 传 nil 表示用场景默认文案；同一场景重复 present 会覆盖文案。
- (void)presentScene:(DCScene)scene content:(NSString *)content;
- (void)dismissScene:(DCScene)scene;

@end
