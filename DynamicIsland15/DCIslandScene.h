#import <Foundation/Foundation.h>

// 灵动岛场景类型
typedef NS_ENUM(NSInteger, DCScene) {
    DCSceneIdle = 0,
    DCSceneMusic,         // 音乐播放
    DCSceneCharging,      // 充电中
    DCSceneNotification,  // 来通知
    DCSceneCall,          // 通话中
};

// 场景优先级：数字越大越优先显示。
// 参考原生灵动岛行为：通话常驻最高，通知即时弹出，充电长驻低优先，音乐长驻最低。
static inline NSInteger DCScenePriority(DCScene s) {
    switch (s) {
        case DCSceneCall:         return 100;
        case DCSceneNotification: return 80;
        case DCSceneCharging:     return 50;
        case DCSceneMusic:        return 30;
        case DCSceneIdle:         return 0;
    }
    return 0;
}

// 通知场景自动收起时长（秒）
static const NSTimeInterval kNotificationSceneDuration = 4.0;
