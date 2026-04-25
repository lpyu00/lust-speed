#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static void (*set_timeScale)(float) = NULL;
static UIButton *floatBtn = nil;
static BOOL speedOn = NO;
static float currentSpeed = 5.0; 
static intptr_t unity_base_addr = 0; 
static CADisplayLink *speedGuard = nil; 
static BOOL isAlertShowing = NO; 

@interface SpeedHackUI : NSObject
+ (void)btnTapped:(UITapGestureRecognizer *)tap;
+ (void)btnDragged:(UIPanGestureRecognizer *)pan;
+ (void)btnLongPressed:(UILongPressGestureRecognizer *)press;
+ (void)keepSpeed:(CADisplayLink *)link;
@end

@implementation SpeedHackUI
+ (void)btnTapped:(UITapGestureRecognizer *)tap {
    speedOn = !speedOn;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [floatBtn setTitle:speedOn ? [NSString stringWithFormat:@"%.0fx", currentSpeed] : @"1x" forState:UIControlStateNormal];
        floatBtn.backgroundColor = speedOn ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    });
    
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

+ (void)btnLongPressed:(UILongPressGestureRecognizer *)press {
    if (press.state == UIGestureRecognizerStateBegan) {
        if (isAlertShowing) return; 
        isAlertShowing = YES;

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"速度设置" 
                                                                       message:@"选择全局加速倍率" 
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        
        NSArray *speeds = @[@1.0, @2.0, @3.0, @5.0, @10.0];
        for (NSNumber *s in speeds) {
            [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@ 倍速", s] 
                                                      style:UIAlertActionStyleDefault 
                                                    handler:^(UIAlertAction *action) {
                currentSpeed = [s floatValue];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [floatBtn setTitle:speedOn ? [NSString stringWithFormat:@"%.0fx", currentSpeed] : @"1x" forState:UIControlStateNormal];
                    floatBtn.backgroundColor = speedOn ? [UIColor systemGreenColor] : [UIColor systemRedColor];
                });
                
                if (speedOn && set_timeScale && (intptr_t)set_timeScale > unity_base_addr && (intptr_t)set_timeScale < unity_base_addr + 0x10000000) {
                    set_timeScale(currentSpeed);
                }
                
                isAlertShowing = NO; 
            }]];
        }
        
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            isAlertShowing = NO; 
        }]];
        
        UIViewController *topVC = floatBtn.window.rootViewController;
        while (topVC.presentedViewController) {
            topVC = topVC.presentedViewController;
        }
        [topVC presentViewController:alert animated:YES completion:nil];
    }
}

+ (void)keepSpeed:(CADisplayLink *)link {
    if (speedOn && set_timeScale && (intptr_t)set_timeScale > unity_base_addr && (intptr_t)set_timeScale < unity_base_addr + 0x10000000) {
        set_timeScale(currentSpeed);
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
            
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:[SpeedHackUI class] action:@selector(btnTapped:)];
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:[SpeedHackUI class] action:@selector(btnLongPressed:)];
            [tap requireGestureRecognizerToFail:longPress]; 
            
            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:[SpeedHackUI class] action:@selector(btnDragged:)];
            
            [floatBtn addGestureRecognizer:tap];
            [floatBtn addGestureRecognizer:longPress];
            [floatBtn addGestureRecognizer:pan];
            
            [win addSubview:floatBtn];
            [win bringSubviewToFront:floatBtn];
            
            speedGuard = [CADisplayLink displayLinkWithTarget:[SpeedHackUI class] selector:@selector(keepSpeed:)];
            
            // 【终极完美调校】：每秒 2 次，完美平衡极低耗电与无感响应！
            if (@available(iOS 15.0, *)) {
                speedGuard.preferredFrameRateRange = CAFrameRateRangeMake(2, 2, 2);
            } else {
                speedGuard.preferredFramesPerSecond = 2;
            }
            [speedGuard addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        }
    });
}

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
