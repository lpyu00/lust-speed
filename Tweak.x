#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#include <string.h>

// 1. 特征码（你提取的神级 AOB）
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

// 2. 按钮点击与拖拽逻辑
void toggleSpeed() {
    speedOn = !speedOn;
    dispatch_async(dispatch_get_main_queue(), ^{
        [floatBtn setTitle:speedOn ? @"5x" : @"1x" forState:UIControlStateNormal];
        floatBtn.backgroundColor = speedOn ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    });
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

// 3. 核心：在游戏完全启动后，再寻找地址并贴上 UI
%hook UnityAppController

- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig; // 先让游戏正常启动
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // --- 步骤 A：修复基址获取，扫描内存 ---
        intptr_t base_addr = 0;
        for (uint32_t i = 0; i < _dyld_image_count(); i++) {
            if (strstr(_dyld_get_image_name(i), "UnityFramework")) {
                // 【核心修复】必须用 header 获取真实物理内存首地址！
                base_addr = (intptr_t)_dyld_get_image_header(i);
                break;
            }
        }
        
        if (base_addr != 0) {
            // 扫描 32MB 范围
            void *func = scanPattern((const uint8_t *)base_addr, 0x2000000);
            if (func) {
                set_timeScale = (void (*)(float))func;
            }
        }
        
        // --- 步骤 B：延迟 3 秒，等 Unity 画面渲染完毕贴 UI ---
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            // 现代获取 Window 的方法
            UIWindow *win = nil;
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    win = scene.windows.firstObject;
                    break;
                }
            }
            if (!win) win = [UIApplication sharedApplication].keyWindow;

            if (win && set_timeScale) {
                // 成功找到特征码，贴上红色的小圆球！
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
                
                // 定时保活
                [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
                    if (speedOn && set_timeScale) set_timeScale(5.0);
                }];
                
            } else if (win && !set_timeScale) {
                // 致命错误：特征码没找到！弹窗报警！
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"扫描失败" 
                                                                               message:@"引擎基址找到了，但特征码不匹配！" 
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
                [win.rootViewController presentViewController:alert animated:YES completion:nil];
            }
        });
    });
}
%end
