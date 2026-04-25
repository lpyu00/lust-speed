#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static void (*set_timeScale)(float) = NULL;
static UIButton *floatBtn = nil;
static BOOL speedOn = NO;
static float currentSpeed = 5.0; // 默认倍数，不再写死
static intptr_t unity_base_addr = 0; // 存一下基址用来做安全校验

@interface SpeedHackUI : NSObject
+ (void)btnTapped;
+ (void)btnDragged:(UIPanGestureRecognizer *)pan;
+ (void)btnLongPressed:(UILongPressGestureRecognizer *)press;
@end

@implementation SpeedHackUI
+ (void)btnTapped {
    speedOn = !speedOn;
    dispatch_async(dispatch_get_main_queue(), ^{
        [floatBtn setTitle:speedOn ? [NSString stringWithFormat:@"%.0fx", currentSpeed] : @"1x" forState:UIControlStateNormal];
        floatBtn.backgroundColor = speedOn ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    });
    
    // 【优化1：添加地址安全范围校验】
    if (set_timeScale && (intptr_t)set_timeScale > unity_base_addr && (intptr_t)set_timeScale < unity_base_addr + 0x10000000) {
        set_timeScale(speedOn ? currentSpeed : 1.0);
    }
}

+ (void)btnDragged:(UIPanGestureRecognizer *)pan {
    UIView *v = pan.view;
    CGPoint t = [pan translationInView:v.superview];
    v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
    [pan setTranslation:CGPointZero inView:v.superview];
}

// 【优化3：新增长按弹出调速菜单】
+ (void)btnLongPressed:(UILongPressGestureRecognizer *)press {
    if (press.state == UIGestureRecognizerStateBegan) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"速度设置" message:@"选择全局加速倍率" preferredStyle:UIAlertControllerStyleActionSheet];
        
        NSArray *speeds = @[@1.0, @2.0, @3.0, @5.0, @10.0];
        for (NSNumber *s in speeds) {
            [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@ 倍速", s] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                currentSpeed = [s floatValue];
                if (speedOn) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [floatBtn setTitle:[NSString stringWithFormat:@"%.0fx", currentSpeed] forState:UIControlStateNormal];
                    });
                    if (set_timeScale) set_timeScale(currentSpeed);
                }
            }]];
        }
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        
        UIViewController *rootVC = floatBtn.window.rootViewController;
        if (rootVC.presentedViewController) rootVC = rootVC.presentedViewController;
        [rootVC presentViewController:alert animated:YES completion:nil];
    }
}
@end

static void initSpeedHack() {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (strstr(_dyld_get_image_name(i), "UnityFramework")) {
            unity_base_addr = (intptr_t)_dyld_get_image_header(i);
            break;
        }
    }
    
    if (unity_base_addr != 0) {
        set_timeScale = (void (*)(float))(unity_base_addr + 0x85D2418);
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
            
            [floatBtn addTarget:[SpeedHackUI class] action:@selector(btnTapped) forControlEvents:UIControlEventTouchUpInside];
            
            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:[SpeedHackUI class] action:@selector(btnDragged:)];
            [floatBtn addGestureRecognizer:pan];
            
            // 绑定长按事件
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:[SpeedHackUI class] action:@selector(btnLongPressed:)];
            [floatBtn addGestureRecognizer:longPress];
            
            [win addSubview:floatBtn];
            [win bringSubviewToFront:floatBtn];
            
            // 【优化2：换用更健壮的 CADisplayLink 绑定屏幕刷新率】
            CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:[SpeedHackUI class] selector:@selector(keepSpeed)];
            [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        }
    });
}

// 补充 CADisplayLink 的执行方法
@implementation SpeedHackUI (DisplayLink)
+ (void)keepSpeed {
    if (speedOn && set_timeScale && (intptr_t)set_timeScale > unity_base_addr && (intptr_t)set_timeScale < unity_base_addr + 0x10000000) {
        set_timeScale(currentSpeed);
    }
}
@end

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
