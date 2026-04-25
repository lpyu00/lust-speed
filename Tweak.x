#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static void (*set_timeScale)(float) = NULL;
static UIButton *floatBtn = nil;
static BOOL speedOn = NO;

// 1. 按钮点击与拖拽逻辑
void toggleSpeed() {
    speedOn = !speedOn;
    dispatch_async(dispatch_get_main_queue(), ^{
        [floatBtn setTitle:speedOn ? @"5x" : @"1x" forState:UIControlStateNormal];
        floatBtn.backgroundColor = speedOn ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    });
    // 点击按钮时，直接向引擎发送倍速指令
    if (set_timeScale) {
        set_timeScale(speedOn ? 5.0 : 1.0);
    }
}

void dragButton(UIPanGestureRecognizer *g) {
    UIView *v = g.view;
    CGPoint t = [g translationInView:v.superview];
    v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
    [g setTranslation:CGPointZero inView:v.superview];
}

// 2. 核心初始化逻辑（直接使用精准地址，拒绝暴力扫描）
static void initSpeedHack() {
    intptr_t base_addr = 0;
    // 获取游戏引擎基址 (这和我们用 Frida 获取基址的原理一模一样)
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (strstr(_dyld_get_image_name(i), "UnityFramework")) {
            base_addr = (intptr_t)_dyld_get_image_header(i);
            break;
        }
    }
    
    // 如果找到了引擎
    if (base_addr != 0) {
        // 直接使用你辛辛苦苦挖出来的绝密坐标，不再进行任何危险扫描！
        set_timeScale = (void (*)(float))(base_addr + 0x85D2418);
    }
    
    // 延迟 3 秒等游戏画面渲染完，贴上按钮
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                win = scene.windows.firstObject;
                break;
            }
        }
        if (!win) win = [UIApplication sharedApplication].keyWindow;

        // 只要画面准备好了，不管三七二十一，直接把按钮扔上去
        if (win) {
            floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            floatBtn.frame = CGRectMake(20, 100, 60, 60);
            floatBtn.backgroundColor = [UIColor systemRedColor];
            floatBtn.layer.cornerRadius = 30;
            [floatBtn setTitle:@"1x" forState:UIControlStateNormal];
            [floatBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [floatBtn.titleLabel setFont:[UIFont boldSystemFontOfSize:18]];
            
            [floatBtn addTarget:nil action:@selector(toggleSpeed) forControlEvents:UIControlEventTouchUpInside];
            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:nil action:@selector(dragButton:)];
            [floatBtn addGestureRecognizer:pan];
            
            [win addSubview:floatBtn];
            
            // 死循环踩油门：防止游戏自动把速度重置为 1
            [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
                if (speedOn && set_timeScale) set_timeScale(5.0);
            }];
        }
    });
}

// 3. 插件启动入口（监听游戏进入前台瞬间触发）
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
