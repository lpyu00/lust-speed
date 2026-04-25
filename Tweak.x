#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static void (*set_timeScale)(float) = NULL;
static UIButton *floatBtn = nil;
static BOOL speedOn = NO;

// ==========================================
// 【核心修复】：必须用苹果原生类来接收点击事件
// ==========================================
@interface SpeedHackUI : NSObject
+ (void)btnTapped;
+ (void)btnDragged:(UIPanGestureRecognizer *)pan;
@end

@implementation SpeedHackUI
+ (void)btnTapped {
    speedOn = !speedOn;
    dispatch_async(dispatch_get_main_queue(), ^{
        [floatBtn setTitle:speedOn ? @"5x" : @"1x" forState:UIControlStateNormal];
        floatBtn.backgroundColor = speedOn ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    });
    if (set_timeScale) set_timeScale(speedOn ? 5.0 : 1.0);
}

+ (void)btnDragged:(UIPanGestureRecognizer *)pan {
    UIView *v = pan.view;
    CGPoint t = [pan translationInView:v.superview];
    v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
    [pan setTranslation:CGPointZero inView:v.superview];
}
@end
// ==========================================

// 初始化逻辑
static void initSpeedHack() {
    intptr_t base_addr = 0;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (strstr(_dyld_get_image_name(i), "UnityFramework")) {
            base_addr = (intptr_t)_dyld_get_image_header(i);
            break;
        }
    }
    
    if (base_addr != 0) {
        set_timeScale = (void (*)(float))(base_addr + 0x85D2418);
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                win = scene.windows.firstObject;
                break;
            }
        }
        if (!win) win = [UIApplication sharedApplication].keyWindow;

        if (win) {
            floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            floatBtn.frame = CGRectMake(20, 100, 60, 60);
            floatBtn.backgroundColor = [UIColor systemRedColor];
            floatBtn.layer.cornerRadius = 30;
            [floatBtn setTitle:@"1x" forState:UIControlStateNormal];
            [floatBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [floatBtn.titleLabel setFont:[UIFont boldSystemFontOfSize:18]];
            
            // 【关键修改】：绑定我们上面写的苹果原生类
            [floatBtn addTarget:[SpeedHackUI class] action:@selector(btnTapped) forControlEvents:UIControlEventTouchUpInside];
            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:[SpeedHackUI class] action:@selector(btnDragged:)];
            [floatBtn addGestureRecognizer:pan];
            
            [win addSubview:floatBtn];
            [win bringSubviewToFront:floatBtn]; // 强制置顶！防止被游戏隐形图层挡住！
            
            [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
                if (speedOn && set_timeScale) set_timeScale(5.0);
            }];
        }
    });
}

// 插件入口
__attribute__((constructor)) static void main_entry() {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification 
                                                      object:nil 
                                                       queue:[NSOperationQueue mainQueue] 
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            initSpeedHack();
        });
    }];
}
