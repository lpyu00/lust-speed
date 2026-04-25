#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#include <string.h>

// 1. 特征码
static const uint8_t kPattern[] = {0xE9, 0x23, 0xBD, 0x6D, 0xF4, 0x4F, 0x01, 0xA9, 0xFD, 0x7B, 0x02, 0xA9};

static void* scanPattern(const uint8_t *base, size_t size) {
    for (size_t i = 0; i < size - sizeof(kPattern); i++) {
        if (memcmp(base + i, kPattern, sizeof(kPattern)) == 0) {
            return (void *)(base + i);
        }
    }
    return NULL;
}

static void (*set_timeScale)(float) = NULL;
static UIButton *floatBtn = nil;
static BOOL speedOn = NO;

// 2. 按钮逻辑
void toggleSpeed() {
    speedOn = !speedOn;
    dispatch_async(dispatch_get_main_queue(), ^{
        [floatBtn setTitle:speedOn ? @"5x" : @"1x" forState:UIControlStateNormal];
        floatBtn.backgroundColor = speedOn ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    });
    if (set_timeScale) set_timeScale(speedOn ? 5.0 : 1.0);
}

void dragButton(UIPanGestureRecognizer *g) {
    UIView *v = g.view;
    CGPoint t = [g translationInView:v.superview];
    v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
    [g setTranslation:CGPointZero inView:v.superview];
}

// 3. 核心初始化逻辑（完全剥离 %hook）
static void initSpeedHack() {
    intptr_t base_addr = 0;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (strstr(_dyld_get_image_name(i), "UnityFramework")) {
            base_addr = (intptr_t)_dyld_get_image_header(i);
            break;
        }
    }
    
    if (base_addr != 0) {
        // 【核心修复】先直接校验你找到的那个绝密地址 (极速秒开)
        void *expected_ptr = (void *)(base_addr + 0x85D2418);
        if (memcmp(expected_ptr, kPattern, sizeof(kPattern)) == 0) {
            set_timeScale = (void (*)(float))expected_ptr;
        } else {
            // 如果游戏更新地址变了，扩大扫描范围到 200MB (0x0C800000) 暴力搜！
            set_timeScale = (void (*)(float))scanPattern((const uint8_t *)base_addr, 0x0C800000);
        }
    }
    
    // 延迟 3 秒贴按钮
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                win = scene.windows.firstObject;
                break;
            }
        }
        if (!win) win = [UIApplication sharedApplication].keyWindow;

        if (win && set_timeScale) {
            // 找到了！贴按钮！
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
            
            [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
                if (speedOn && set_timeScale) set_timeScale(5.0);
            }];
        } else if (win && !set_timeScale) {
            // 找不到了！弹出报警弹窗！
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"扫描失败" 
                                                                           message:@"由于范围或特征码变动，无法定位加速引擎！" 
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:nil]];
            [win.rootViewController presentViewController:alert animated:YES completion:nil];
        }
    });
}

// 4. 【灵魂修复】C语言底层入口，插件被加载瞬间自动执行！不需要越狱环境！
__attribute__((constructor)) static void main_entry() {
    // 监听苹果系统原生广播：当 App 启动完成进入前台时
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
