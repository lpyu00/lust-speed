#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#include <string.h>

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

static void createButton() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = [UIApplication sharedApplication].keyWindow;
        floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        floatBtn.frame = CGRectMake(100, 200, 60, 60);
        floatBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.4 alpha:0.8];
        floatBtn.layer.cornerRadius = 30;
        [floatBtn setTitle:@"1x" forState:UIControlStateNormal];
        [floatBtn addTarget:nil action:@selector(toggleSpeed) forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:nil action:@selector(dragButton:)];
        [floatBtn addGestureRecognizer:pan];
        [win addSubview:floatBtn];
    });
}

void toggleSpeed() {
    speedOn = !speedOn;
    dispatch_async(dispatch_get_main_queue(), ^{
        [floatBtn setTitle:speedOn ? @"5x" : @"1x" forState:UIControlStateNormal];
    });
    if (set_timeScale) {
        set_timeScale(speedOn ? 5.0 : 1.0);
    }
}

void dragButton(UIPanGestureRecognizer *g) {
    UIView *v = g.view;
    CGPoint t = [g translationInView:v];
    v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
    [g setTranslation:CGPointZero inView:v];
}

static void keepSpeed() {
    if (speedOn && set_timeScale) {
        set_timeScale(5.0);
    }
}

%ctor {
    intptr_t base = 0;
    size_t size = 0;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (strstr(_dyld_get_image_name(i), "UnityFramework")) {
            base = _dyld_get_image_vmaddr_slide(i);
            size = 0x1000000;
            break;
        }
    }
    if (!base) return;

    void *func = scanPattern((const uint8_t *)base, size);
    if (!func) return;

    set_timeScale = (void (*)(float))func;

    createButton();

    [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
        keepSpeed();
    }];
}
