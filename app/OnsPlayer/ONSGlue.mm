// =============================================================================
// ONSGlue.mm - ONScripter standalone player glue (GPU-free presentation)
//
// WHY: on this jailbroken environment MTLCreateSystemDefaultDevice() returns nil
// and GL ES contexts cannot be created, so SDL's metal/opengles/software
// renderers all fail. CoreAnimation compositing still works (system-side), so we
// present engine frames by assigning CGImage to layer.contents - zero GPU client
// access needed.
//
// Flow:
//   1. read marker /var/mobile/Documents/Galgames/.ons_launch  (line 1 = game dir)
//   2. chdir into game dir
//   3. create UIWindow + frame view, register presenter with the compat layer
//   4. touches -> synthesized SDL mouse events (tap=advance, 2-finger=menu, hold=skip)
//   5. call ons_main(1, argv)   (no bare-dir argument: ONS would optionHelp()+exit)
// =============================================================================
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>

#define SDL_MAIN_HANDLED 1
#include <SDL.h>

#include <unistd.h>
#include <sys/stat.h>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <thread>
#include <chrono>

int ons_main(int argc, char **argv);
extern "C" void onsdl_set_scale_mode(int stretch);
extern "C" void onsdl_set_presenter(void (*fn)(const void *pixels, int w, int h, int pitch));
extern "C" unsigned int onsdl_window_id(void);

static const char *K_MARKER = "/var/mobile/Documents/Galgames/.ons_launch";
static const Uint32 LONG_PRESS_MS = 450;

// ---------------------------------------------------------------------------
// runtime state shared with the presenter / touch code
// ---------------------------------------------------------------------------
static int    gGameW = 640, gGameH = 480;
static UIView *gFrameView = nil;
static UIWindow *gWindow = nil;
static volatile bool gSkipMode = false;
static bool gFillScreen = false;   // true = 拉伸铺满，false = 等比黑边
static int  gSkipMs = 160;         // 快进连点间隔（由设置页「快进速度」换算）
static int  gVolume = 75;          // 0-100

extern "C" int Mix_Volume(int channel, int volume);
static bool   gSingleDown = false;
static CGPoint gLastPoint = CGPointMake(0, 0);

// ---------------------------------------------------------------------------
// SDL event synthesis (works even if SDL never created a renderer)
// ---------------------------------------------------------------------------
static void pushMouse(Uint32 type, Uint8 button, Sint32 x, Sint32 y) {
    SDL_Event ev; SDL_zero(ev);
    if (type == SDL_MOUSEMOTION) {
        ev.motion.type = SDL_MOUSEMOTION;
        ev.motion.x = x; ev.motion.y = y;
        ev.motion.windowID = onsdl_window_id();
    } else {
        ev.button.type = type;
        ev.button.button = button;
        ev.button.state = (type == SDL_MOUSEBUTTONDOWN) ? SDL_PRESSED : SDL_RELEASED;
        ev.button.clicks = 1;
        ev.button.x = x; ev.button.y = y;
        ev.button.windowID = onsdl_window_id();
    }
    SDL_PushEvent(&ev);
}

static void pushCtrl(bool down) {
    SDL_Event ev; SDL_zero(ev);
    ev.key.type = down ? SDL_KEYDOWN : SDL_KEYUP;
    ev.key.state = down ? SDL_PRESSED : SDL_RELEASED;
    ev.key.keysym.sym = SDLK_LCTRL;
    ev.key.windowID = onsdl_window_id();
    SDL_PushEvent(&ev);
}

// view point -> game pixel coordinates (aspect-fit letterbox)
static void gamePoint(CGPoint p, Sint32 *ox, Sint32 *oy) {
    CGFloat vw = gFrameView ? gFrameView.bounds.size.width  : 1;
    CGFloat vh = gFrameView ? gFrameView.bounds.size.height : 1;
    if (vw < 1) vw = 1;
    if (vh < 1) vh = 1;
    CGFloat scale = MIN(vw / gGameW, vh / gGameH);
    CGFloat cw = gGameW * scale, ch = gGameH * scale;
    CGFloat left = (vw - cw) / 2, top = (vh - ch) / 2;
    CGFloat gx = (p.x - left) / cw * gGameW;
    CGFloat gy = (p.y - top)  / ch * gGameH;
    if (gx < 0) gx = 0; if (gx >= gGameW) gx = gGameW - 1;
    if (gy < 0) gy = 0; if (gy >= gGameH) gy = gGameH - 1;
    *ox = (Sint32)gx; *oy = (Sint32)gy;
}

// ---------------------------------------------------------------------------
// presenter: engine pixels -> CALayer.contents (system compositor, no GPU client)
// ---------------------------------------------------------------------------
static void present_pixels(const void *px, int w, int h, int pitch) {
    if (!px || w <= 0 || h <= 0) return;
    @autoreleasepool {
        gGameW = w; gGameH = h;
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        // ONS 使用 ARGB8888；小端内存布局 = BGRA -> kCGImageAlphaPremultipliedFirst|32Little
        CGContextRef ctx = CGBitmapContextCreate((void *)px, (size_t)w, (size_t)h, 8,
                                                 (size_t)pitch, cs,
                                                 kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
        if (ctx) {
            CGImageRef img = CGBitmapContextCreateImage(ctx);
            if (img) {
                gFrameView.layer.contentsGravity = gFillScreen ? kCAGravityResize : kCAGravityResizeAspect;
                gFrameView.layer.contents = (__bridge id)img;
                CGImageRelease(img);
            }
            CGContextRelease(ctx);
        }
        CGColorSpaceRelease(cs);
    }
}


// ---------------------------------------------------------------------------
// back to library
//   ONS 的 end/quit 会直接 exit()，必须自己提供可靠回库入口
// ---------------------------------------------------------------------------
static volatile bool gBackDone = false;

static void openLibraryURL(void) {
    @autoreleasepool {
        NSURL *url = [NSURL URLWithString:@"galplayer://return"];
        UIApplication *app = [UIApplication sharedApplication];
        if (app && url) {
            [app openURL:url options:@{} completionHandler:nil];
            fprintf(stderr, "[ONSApp] back to GalPlayer\n");
        }
    }
}

static void requestBackToLibrary(void) {
    if (gBackDone) return;
    gBackDone = true;
    openLibraryURL();
    // 给系统一点时间切换，再结束本进程
    usleep(1500 * 1000);   // 等 SpringBoard 完成 App 切换
    exit(0);
}

static void atexitBack(void) { openLibraryURL(); usleep(1500 * 1000); }

// ---------------------------------------------------------------------------
// frame view with touch handling
// ---------------------------------------------------------------------------
@interface ONSFrameView : UIView
@end

@implementation ONSFrameView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        self.multipleTouchEnabled = YES;
        self.layer.contentsGravity = kCAGravityResizeAspect;
        self.layer.magnificationFilter = kCAFilterLinear;
        self.layer.minificationFilter = kCAFilterLinear;

        // 左上角返回按钮（44pt 命中区，半透明，不抢游戏画面）
        UIButton *back = [UIButton buttonWithType:UIButtonTypeSystem];
        back.frame = CGRectMake(18, 18, 44, 44);
        back.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
        back.layer.cornerRadius = 22;
        back.tintColor = [UIColor whiteColor];
        UIImage *img = [UIImage systemImageNamed:@"chevron.left"];
        [back setImage:img forState:UIControlStateNormal];
        back.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
        [back addTarget:self action:@selector(tapBack) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:back];
    }
    return self;
}

- (void)tapBack {
    requestBackToLibrary();
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    NSInteger n = touches.count;
    UITouch *t = touches.anyObject;
    Sint32 gx, gy; gamePoint([t locationInView:self], &gx, &gy);
    gLastPoint = [t locationInView:self];

    if (n >= 2) {
        // two-finger: cancel single click, then right click on release
        if (gSingleDown) { pushMouse(SDL_MOUSEBUTTONUP, SDL_BUTTON_LEFT, gx, gy); gSingleDown = false; }
        if (gSkipMode) { pushCtrl(false); gSkipMode = false; }
        return;
    }
    pushMouse(SDL_MOUSEMOTION, 0, gx, gy);
    pushMouse(SDL_MOUSEBUTTONDOWN, SDL_BUTTON_LEFT, gx, gy);
    gSingleDown = true;

    // long press -> skip mode (hold ctrl + auto clicks)
    __weak UIView *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LONG_PRESS_MS * NSEC_PER_MSEC)),
                   dispatch_get_main_queue(), ^{
        if (!gSingleDown || gSkipMode || weakSelf == nil) return;
        Sint32 x, y; gamePoint(gLastPoint, &x, &y);
        pushMouse(SDL_MOUSEBUTTONUP, SDL_BUTTON_LEFT, x, y);
        gSingleDown = false;
        pushCtrl(true);
        gSkipMode = true;
        [self skipTick];
    });
}

- (void)skipTick {
    if (!gSkipMode) return;
    Sint32 x, y; gamePoint(gLastPoint, &x, &y);
    pushMouse(SDL_MOUSEBUTTONDOWN, SDL_BUTTON_LEFT, x, y);
    pushMouse(SDL_MOUSEBUTTONUP, SDL_BUTTON_LEFT, x, y);
    __weak ONSFrameView *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(160 * NSEC_PER_MSEC)),
                   dispatch_get_main_queue(), ^{ [weakSelf skipTick]; });
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *t = touches.anyObject;
    CGPoint p = [t locationInView:self];
    gLastPoint = p;
    Sint32 gx, gy; gamePoint(p, &gx, &gy);
    if (gSingleDown) pushMouse(SDL_MOUSEMOTION, 0, gx, gy);
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *t = touches.anyObject;
    Sint32 gx, gy; gamePoint([t locationInView:self], &gx, &gy);
    if (gSkipMode) { pushCtrl(false); gSkipMode = false; return; }
    if (gSingleDown) {
        pushMouse(SDL_MOUSEBUTTONUP, SDL_BUTTON_LEFT, gx, gy);
        gSingleDown = false;
    } else if (event.allTouches.count == 0) {
        // two-finger tap ended -> right click (menu)
        pushMouse(SDL_MOUSEBUTTONDOWN, SDL_BUTTON_RIGHT, gx, gy);
        pushMouse(SDL_MOUSEBUTTONUP, SDL_BUTTON_RIGHT, gx, gy);
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (gSkipMode) { pushCtrl(false); gSkipMode = false; }
    if (gSingleDown) { gSingleDown = false; }
}

@end

// ---------------------------------------------------------------------------
static void setupUIKit(void) {
    void (^build)(void) = ^{
        if (gWindow) return;
        UIWindow *win = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        ONSFrameView *view = [[ONSFrameView alloc] initWithFrame:win.bounds];
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor blackColor];
        [vc.view addSubview:view];
        win.rootViewController = vc;
        win.backgroundColor = [UIColor blackColor];
        // SDL 自己的窗口会随后创建；把我们的窗口抬到更高层级，保证画面与触摸都由我们接管
        win.windowLevel = UIWindowLevelStatusBar + 1.0;
        [win makeKeyAndVisible];
        gWindow = win;
        gFrameView = view;
        fprintf(stderr, "[ONSApp] UIKit window ready %.0fx%.0f\n",
                (double)win.bounds.size.width, (double)win.bounds.size.height);
    };
    if ([NSThread isMainThread]) build();
    else dispatch_sync(dispatch_get_main_queue(), build);
}

// ---------------------------------------------------------------------------
int GP_ONS_Entry(int argc, char **argv) {
    if (FILE *lf = fopen("/var/mobile/Documents/ons_runtime.log", "w")) {
        dup2(fileno(lf), 1); dup2(fileno(lf), 2);
        setvbuf(stdout, nullptr, _IONBF, 0);
        setvbuf(stderr, nullptr, _IONBF, 0);
    }
    fprintf(stderr, "[ONSApp] start argc=%d\n", argc);

    // marker
    std::string gameDir;
    int stretch = 0;
    if (FILE *fp = fopen(K_MARKER, "r")) {
        char line[1024];
        if (fgets(line, sizeof(line), fp)) {
            size_t n = strlen(line);
            while (n && (line[n-1] == '\n' || line[n-1] == '\r')) line[--n] = 0;
            gameDir = line;
        }
        // 第 2 行 = 是否拉伸全屏
        if (fgets(line, sizeof(line), fp)) stretch = (line[0] == '1') ? 1 : 0;
        // 第 3 行 = 快进间隔毫秒
        if (fgets(line, sizeof(line), fp)) {
            int v = atoi(line);
            if (v >= 40 && v <= 2000) gSkipMs = v;
        }
        // 第 4 行 = 音量
        if (fgets(line, sizeof(line), fp)) {
            int v = atoi(line);
            if (v >= 0 && v <= 100) gVolume = v;
        }
        fclose(fp);
        unlink(K_MARKER);
    }
    if (gameDir.empty()) gameDir = "/var/mobile/Documents/Galgames";
    fprintf(stderr, "[ONSApp] gameDir=%s\n", gameDir.c_str());
    if (::chdir(gameDir.c_str()) != 0)
        fprintf(stderr, "[ONSApp] chdir failed errno=%d\n", errno);
    char cwd[1024] = {0};
    if (getcwd(cwd, sizeof(cwd))) fprintf(stderr, "[ONSApp] cwd=%s\n", cwd);

    const char *scripts[] = {"0.txt", "00.txt", "nscript.dat", "nscript.___"};
    for (int i = 0; i < 4; ++i)
        if (access(scripts[i], R_OK) == 0)
            fprintf(stderr, "[ONSApp] script found: %s\n", scripts[i]);

    {
        id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
        fprintf(stderr, "[ONSApp] probe MTLDevice=%s\n", dev ? "OK" : "nil");
    }

    // UIKit presentation (GPU-free) + compat hooks
    setupUIKit();
    onsdl_set_presenter(present_pixels);

    SDL_SetHint(SDL_HINT_ORIENTATIONS, "LandscapeLeft LandscapeRight");
    SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS, "0");
    SDL_SetHint(SDL_HINT_MOUSE_TOUCH_EVENTS, "0");
    gFillScreen = (stretch != 0);
    onsdl_set_scale_mode(stretch);

    atexit(atexitBack);   // 引擎 exit() 时也能回库

    // 引擎初始化完 mixer 后应用音量设置
    {
        int vol = gVolume;
        static int sVol = 0;
        sVol = vol;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            usleep(1800 * 1000);
            Mix_Volume(-1, sVol * 128 / 100);
            fprintf(stderr, "[ONSApp] volume applied: %d\n", sVol);
        });
    }
    std::string a0 = "onscripter";
    std::string fontPath;
    {
        // 注意: @[...] 字面量禁止 nil 元素，必须逐个判空后 addObject
        NSMutableArray *cands = [NSMutableArray array];
        NSString *p1 = [[NSBundle mainBundle] pathForResource:@"DroidSansFallback" ofType:@"ttf"];
        if (p1) [cands addObject:p1];
        NSString *p2 = [[NSBundle mainBundle] pathForResource:@"LXGWWenKai-Regular" ofType:@"ttf"];
        if (p2) [cands addObject:p2];
        [cands addObject:@"/var/mobile/Documents/Galgames/default.ttf"];
        fprintf(stderr, "[ONSApp] font candidates=%lu\n", (unsigned long)cands.count);
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *p in cands) {
            if ([fm fileExistsAtPath:p]) { fontPath = [p UTF8String]; break; }
        }
    }
    std::string a1 = "-f";
    // 若游戏目录里自带 default.ttf，就不用 -f（让引擎自取，避免覆盖作者字体）
    std::vector<std::string> args;
    args.push_back(a0);
    if (!fontPath.empty() && access("default.ttf", R_OK) != 0) {
        fprintf(stderr, "[ONSApp] font=%s\n", fontPath.c_str());
        args.push_back(a1);
        args.push_back(fontPath);
    }
    std::vector<char *> avp;
    for (size_t i = 0; i < args.size(); ++i) avp.push_back(const_cast<char *>(args[i].c_str()));
    avp.push_back(nullptr);
    int rc = ons_main((int)args.size(), avp.data());
    fprintf(stderr, "[ONSApp] ons_main returned rc=%d\n", rc);

    // 退出游戏后自动回到 GalPlayer 游戏库
    @autoreleasepool {
        // 先把自己的窗口藏掉，让 SpringBoard 有目标可回落
        if (gWindow) { gWindow.hidden = YES; }
        // 用 URL scheme 唤起宿主：系统会保证切到前台（LSApplicationWorkspace 只启动不激活）
        NSURL *url = [NSURL URLWithString:@"galplayer://return"];
        UIApplication *app = [UIApplication sharedApplication];
        if (app && url) {
            [app openURL:url options:@{} completionHandler:nil];
            fprintf(stderr, "[ONSApp] back to GalPlayer via url scheme\n");
        }
        // 给宿主 App 一点时间完成激活，再退出本进程
        usleep(1200 * 1000);
    }
    return rc;
}
