#import <Cocoa/Cocoa.h>

@interface PixelUsageView : NSView
@property(nonatomic, copy) NSString *errorText;
@property(nonatomic) double primaryRemaining;
@property(nonatomic) double primaryUsed;
@property(nonatomic, copy) NSString *primaryReset;
@property(nonatomic) double secondaryRemaining;
@property(nonatomic) double secondaryUsed;
@property(nonatomic, copy) NSString *secondaryReset;
@property(nonatomic, copy) NSString *plan;
@property(nonatomic, copy) NSString *credits;
@property(nonatomic) BOOL busy;
@property(nonatomic) NSInteger animationFrame;
@property(nonatomic, weak) id target;
@property(nonatomic) SEL refreshAction;
@property(nonatomic) SEL openAction;
@property(nonatomic) SEL quitAction;
@end

@implementation PixelUsageView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _primaryRemaining = -1;
        _secondaryRemaining = -1;
        _primaryReset = @"-";
        _secondaryReset = @"-";
        _plan = @"-";
        _credits = @"-";
    }
    return self;
}

- (BOOL)isFlipped {
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSRect bounds = self.bounds;
    [[NSColor clearColor] setFill];
    NSRectFill(bounds);

    NSRect card = NSInsetRect(bounds, 2, 2);
    [self fillRoundedRect:card radius:15 color:[NSColor colorWithCalibratedRed:0.09 green:0.10 blue:0.11 alpha:1.0]];
    [self strokeRoundedRect:card radius:15 color:[NSColor colorWithCalibratedRed:0.92 green:0.94 blue:0.84 alpha:1.0] width:2];
    [self drawTopHealthBarInRect:NSMakeRect(12, 12, bounds.size.width - 24, 6)];

    NSDictionary *titleAttrs = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:14 weight:NSFontWeightBold],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:0.95 green:0.96 blue:0.88 alpha:1.0]
    };
    [@"用量状态" drawAtPoint:NSMakePoint(18, 22) withAttributes:titleAttrs];

    if (self.errorText.length > 0) {
        NSDictionary *errAttrs = @{
            NSFontAttributeName: [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightMedium],
            NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:1.0 green:0.38 blue:0.32 alpha:1.0]
        };
        [self.errorText drawInRect:NSMakeRect(18, 58, bounds.size.width - 36, 80) withAttributes:errAttrs];
        return;
    }

    [self drawRowWithLabel:@"5 小时" icon:@"heart" remaining:self.primaryRemaining used:self.primaryUsed reset:self.primaryReset y:54];
    [self drawRowWithLabel:@"1 周" icon:@"shield" remaining:self.secondaryRemaining used:self.secondaryUsed reset:self.secondaryReset y:150];

    NSDictionary *footAttrs = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:0.68 green:0.72 blue:0.66 alpha:1.0]
    };
    NSString *footer = [NSString stringWithFormat:@"套餐 %@   重置券 %@", self.plan ?: @"-", self.credits ?: @"-"];
    [footer drawAtPoint:NSMakePoint(18, 236) withAttributes:footAttrs];
    [self drawButtonWithTitle:@"刷新" rect:[self refreshButtonRect] color:[NSColor colorWithCalibratedRed:0.24 green:0.70 blue:0.62 alpha:1.0]];
    [self drawButtonWithTitle:@"详情" rect:[self openButtonRect] color:[NSColor colorWithCalibratedRed:0.42 green:0.55 blue:0.86 alpha:1.0]];
    [self drawButtonWithTitle:@"退出" rect:[self quitButtonRect] color:[NSColor colorWithCalibratedRed:0.78 green:0.31 blue:0.28 alpha:1.0]];
}

- (void)drawRowWithLabel:(NSString *)label icon:(NSString *)icon remaining:(double)remaining used:(double)used reset:(NSString *)reset y:(CGFloat)y {
    NSColor *rowColor = [self colorForRemaining:remaining];
    NSRect rowRect = NSMakeRect(14, y - 6, self.bounds.size.width - 28, 86);
    [self fillRoundedRect:rowRect radius:15 color:[NSColor colorWithCalibratedRed:0.13 green:0.15 blue:0.16 alpha:1.0]];
    [self strokeRoundedRect:rowRect radius:15 color:rowColor width:1.5];

    NSDictionary *labelAttrs = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightBold],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:0.95 green:0.96 blue:0.88 alpha:1.0]
    };
    NSDictionary *valueAttrs = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightBold],
        NSForegroundColorAttributeName: rowColor
    };
    NSDictionary *smallAttrs = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:0.68 green:0.72 blue:0.66 alpha:1.0]
    };

    [label drawAtPoint:NSMakePoint(24, y) withAttributes:labelAttrs];
    NSString *value = remaining >= 0 ? [NSString stringWithFormat:@"剩余 %.0f%%", remaining] : @"剩余 -";
    [value drawAtPoint:NSMakePoint(224, y) withAttributes:valueAttrs];

    CGFloat x = 24;
    CGFloat iconY = y + 22;
    NSInteger filled = remaining >= 0 ? (NSInteger)ceil(MAX(0, MIN(100, remaining)) / 10.0) : 0;
    for (NSInteger i = 0; i < 10; i++) {
        NSColor *color = i < filled ? rowColor : [NSColor colorWithCalibratedRed:0.25 green:0.27 blue:0.27 alpha:1.0];
        if ([icon isEqualToString:@"heart"]) {
            [self drawHeartAt:NSMakePoint(x + i * 17, iconY) color:color];
        } else {
            [self drawShieldAt:NSMakePoint(x + i * 17, iconY) color:color];
        }
    }

    CGFloat barX = 24;
    CGFloat barY = y + 42;
    CGFloat barW = self.bounds.size.width - 48;
    [self fillRoundedRect:NSMakeRect(barX, barY, barW, 8) radius:4 color:[NSColor colorWithCalibratedRed:0.20 green:0.22 blue:0.23 alpha:1.0]];
    [self fillRoundedRect:NSMakeRect(barX, barY, barW * MAX(0, MIN(100, remaining)) / 100.0, 8) radius:4 color:rowColor];

    NSString *usedDetail = [NSString stringWithFormat:@"已用 %.0f%%", used];
    NSString *resetDetail = [NSString stringWithFormat:@"%@ 重置", reset ?: @"-"];
    NSRect detailRect = NSMakeRect(24, y + 58, self.bounds.size.width - 48, 18);
    [self fillRoundedRect:detailRect radius:8.5 color:[NSColor colorWithCalibratedRed:0.18 green:0.20 blue:0.20 alpha:1.0]];
    [usedDetail drawAtPoint:NSMakePoint(34, y + 60) withAttributes:smallAttrs];
    NSSize resetSize = [resetDetail sizeWithAttributes:smallAttrs];
    [resetDetail drawAtPoint:NSMakePoint(NSMaxX(detailRect) - resetSize.width - 12, y + 60) withAttributes:smallAttrs];
}

- (NSColor *)colorForRemaining:(double)remaining {
    double t = MAX(0, MIN(100, remaining)) / 100.0;
    double r = (1.0 - t) * 0.92 + t * 0.16;
    double g = (1.0 - t) * 0.22 + t * 0.82;
    double b = (1.0 - t) * 0.18 + t * 0.36;
    return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0];
}

- (NSArray<NSColor *> *)rainbowColors {
    return @[
        [NSColor colorWithCalibratedRed:1.00 green:0.28 blue:0.25 alpha:1.0],
        [NSColor colorWithCalibratedRed:1.00 green:0.62 blue:0.20 alpha:1.0],
        [NSColor colorWithCalibratedRed:0.98 green:0.86 blue:0.24 alpha:1.0],
        [NSColor colorWithCalibratedRed:0.26 green:0.86 blue:0.38 alpha:1.0],
        [NSColor colorWithCalibratedRed:0.25 green:0.74 blue:1.00 alpha:1.0],
        [NSColor colorWithCalibratedRed:0.58 green:0.42 blue:1.00 alpha:1.0]
    ];
}

- (void)drawTopHealthBarInRect:(NSRect)rect {
    if (!self.busy) {
        [self fillRoundedRect:rect radius:3 color:[self colorForRemaining:self.primaryRemaining]];
        return;
    }

    [self fillRoundedRect:rect radius:3 color:[NSColor colorWithCalibratedRed:0.20 green:0.22 blue:0.23 alpha:1.0]];
    NSBezierPath *clip = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:3 yRadius:3];
    [NSGraphicsContext saveGraphicsState];
    [clip addClip];

    NSArray<NSColor *> *colors = [self rainbowColors];
    CGFloat stripeW = 14;
    CGFloat cycleW = stripeW * colors.count;
    CGFloat offset = fmod((CGFloat)self.animationFrame * 2.0, cycleW);
    for (CGFloat x = rect.origin.x - stripeW - offset; x < NSMaxX(rect) + stripeW; x += stripeW) {
        NSInteger index = (NSInteger)floor((x - rect.origin.x + offset) / stripeW);
        NSColor *color = colors[((index % colors.count) + colors.count) % colors.count];
        [color setFill];
        NSRectFill(NSMakeRect(x, rect.origin.y, stripeW + 1, rect.size.height));
    }

    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawPixel:(NSRect)rect color:(NSColor *)color {
    [color setFill];
    NSRectFill(rect);
}

- (void)fillRoundedRect:(NSRect)rect radius:(CGFloat)radius color:(NSColor *)color {
    [color setFill];
    [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius] fill];
}

- (void)strokeRoundedRect:(NSRect)rect radius:(CGFloat)radius color:(NSColor *)color width:(CGFloat)width {
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];
    path.lineWidth = width;
    [color setStroke];
    [path stroke];
}

- (void)drawHeartAt:(NSPoint)p color:(NSColor *)color {
    CGFloat u = 2;
    int cells[][2] = {{1,0},{2,0},{4,0},{5,0},{0,1},{3,1},{6,1},{0,2},{6,2},{1,3},{5,3},{2,4},{4,4},{3,5}};
    for (int i = 0; i < 14; i++) {
        [self drawPixel:NSMakeRect(p.x + cells[i][0] * u, p.y + cells[i][1] * u, u, u) color:color];
    }
}

- (void)drawShieldAt:(NSPoint)p color:(NSColor *)color {
    CGFloat u = 2;
    int cells[][2] = {{1,0},{2,0},{3,0},{4,0},{5,0},{0,1},{6,1},{0,2},{6,2},{1,3},{5,3},{2,4},{4,4},{3,5}};
    for (int i = 0; i < 14; i++) {
        [self drawPixel:NSMakeRect(p.x + cells[i][0] * u, p.y + cells[i][1] * u, u, u) color:color];
    }
}

- (NSRect)refreshButtonRect {
    return NSMakeRect(18, 258, 82, 28);
}

- (NSRect)openButtonRect {
    return NSMakeRect(119, 258, 82, 28);
}

- (NSRect)quitButtonRect {
    return NSMakeRect(220, 258, 82, 28);
}

- (void)drawButtonWithTitle:(NSString *)title rect:(NSRect)rect color:(NSColor *)color {
    [self fillRoundedRect:rect radius:15 color:color];
    [self strokeRoundedRect:rect radius:15 color:[NSColor colorWithCalibratedWhite:1.0 alpha:0.35] width:1.5];

    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightBold],
        NSForegroundColorAttributeName: [NSColor whiteColor]
    };
    NSSize textSize = [title sizeWithAttributes:attrs];
    [title drawAtPoint:NSMakePoint(NSMidX(rect) - textSize.width / 2, NSMidY(rect) - textSize.height / 2 + 1) withAttributes:attrs];
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    NSPoint flippedPoint = NSMakePoint(point.x, self.bounds.size.height - point.y);
    if ([self point:point orFlippedPoint:flippedPoint inRect:[self refreshButtonRect]]) {
        [self sendAction:self.refreshAction];
    } else if ([self point:point orFlippedPoint:flippedPoint inRect:[self openButtonRect]]) {
        [self sendAction:self.openAction];
    } else if ([self point:point orFlippedPoint:flippedPoint inRect:[self quitButtonRect]]) {
        [self sendAction:self.quitAction];
    }
}

- (BOOL)point:(NSPoint)point orFlippedPoint:(NSPoint)flippedPoint inRect:(NSRect)rect {
    return NSPointInRect(point, rect) || NSPointInRect(flippedPoint, rect);
}

- (void)sendAction:(SEL)action {
    if (self.target && action && [self.target respondsToSelector:action]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.target performSelector:action withObject:self];
#pragma clang diagnostic pop
    }
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong) NSTimer *animationTimer;
@property(nonatomic, strong) NSTask *serverTask;
@property(nonatomic, strong) NSDictionary *lastSnapshot;
@property(nonatomic, strong) PixelUsageView *usageView;
@property(nonatomic) BOOL busy;
@property(nonatomic) BOOL sawBusy;
@property(nonatomic) NSInteger animationFrame;
@property(nonatomic) double lastRemaining;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [NSUserNotificationCenter defaultUserNotificationCenter].delegate = self;

    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.lastRemaining = 100;
    self.statusItem.button.image = [self pixelCatImageWithRemaining:100 busy:NO frame:0];
    self.statusItem.button.imagePosition = NSImageLeft;
    self.statusItem.button.title = @" --";

    NSMenu *menu = [[NSMenu alloc] init];
    self.usageView = [[PixelUsageView alloc] initWithFrame:NSMakeRect(0, 0, 320, 300)];
    self.usageView.target = self;
    self.usageView.refreshAction = @selector(refreshFromMenu:);
    self.usageView.openAction = @selector(openDashboard:);
    self.usageView.quitAction = @selector(quit:);
    NSMenuItem *panelItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    panelItem.view = self.usageView;
    [menu addItem:panelItem];
    self.statusItem.menu = menu;

    [self checkStatusWithCompletion:^(NSDictionary *snapshot) {
        if (!snapshot) {
            [self startBundledServer];
        }
        [self refresh];
    }];

    self.timer = [NSTimer timerWithTimeInterval:5 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    if (self.serverTask && self.serverTask.isRunning) {
        [self.serverTask terminate];
    }
    [self.animationTimer invalidate];
}

- (void)refreshFromMenu:(id)sender {
    [self.usageView setNeedsDisplay:YES];
    [self refresh];
}

- (void)refresh {
    [self checkStatusWithCompletion:^(NSDictionary *snapshot) {
        if (snapshot) {
            self.lastSnapshot = snapshot;
            NSDictionary *primary = [self primaryWindowFromSnapshot:snapshot];
            NSNumber *used = primary[@"usedPercent"];
            double remaining = used ? 100 - used.doubleValue : -1;
            self.lastRemaining = remaining >= 0 ? remaining : self.lastRemaining;
            [self updateBusy:[snapshot[@"busy"] boolValue]];
            self.statusItem.button.title = used ? [NSString stringWithFormat:@" %.0f%%", remaining] : @" --";
            self.statusItem.button.image = [self pixelCatImageWithRemaining:self.lastRemaining busy:self.busy frame:self.animationFrame];
            [self updateMenuWithSnapshot:snapshot error:nil];
        } else {
            self.statusItem.button.title = @" --";
            [self updateBusy:NO];
            self.statusItem.button.image = [self pixelCatImageWithRemaining:0 busy:NO frame:0];
            [self updateMenuWithSnapshot:self.lastSnapshot error:@"本地状态服务未连接"];
            [self startBundledServer];
        }
    }];
}

- (void)checkStatusWithCompletion:(void (^)(NSDictionary *snapshot))completion {
    NSURL *url = [NSURL URLWithString:@"http://127.0.0.1:3333/api/status"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 4;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *snapshot = nil;
        if (data && !error) {
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json isKindOfClass:[NSDictionary class]]) {
                snapshot = (NSDictionary *)json;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(snapshot);
        });
    }];
    [task resume];
}

- (NSDictionary *)codexBucketFromSnapshot:(NSDictionary *)snapshot {
    NSDictionary *data = [snapshot[@"data"] isKindOfClass:[NSDictionary class]] ? snapshot[@"data"] : nil;
    NSDictionary *byId = [data[@"rateLimitsByLimitId"] isKindOfClass:[NSDictionary class]] ? data[@"rateLimitsByLimitId"] : nil;
    NSDictionary *codex = [byId[@"codex"] isKindOfClass:[NSDictionary class]] ? byId[@"codex"] : nil;
    NSDictionary *fallback = [data[@"rateLimits"] isKindOfClass:[NSDictionary class]] ? data[@"rateLimits"] : nil;
    return codex ?: fallback;
}

- (NSDictionary *)primaryWindowFromSnapshot:(NSDictionary *)snapshot {
    NSDictionary *bucket = [self codexBucketFromSnapshot:snapshot];
    return [bucket[@"primary"] isKindOfClass:[NSDictionary class]] ? bucket[@"primary"] : nil;
}

- (void)updateMenuWithSnapshot:(NSDictionary *)snapshot error:(NSString *)error {
    if (error) {
        self.usageView.errorText = [NSString stringWithFormat:@"状态：%@", error];
        [self.usageView setNeedsDisplay:YES];
        return;
    }

    NSDictionary *bucket = [self codexBucketFromSnapshot:snapshot];
    NSDictionary *primary = [bucket[@"primary"] isKindOfClass:[NSDictionary class]] ? bucket[@"primary"] : nil;
    NSDictionary *secondary = [bucket[@"secondary"] isKindOfClass:[NSDictionary class]] ? bucket[@"secondary"] : nil;
    NSDictionary *data = [snapshot[@"data"] isKindOfClass:[NSDictionary class]] ? snapshot[@"data"] : nil;
    NSDictionary *reset = [data[@"rateLimitResetCredits"] isKindOfClass:[NSDictionary class]] ? data[@"rateLimitResetCredits"] : nil;

    self.usageView.errorText = nil;
    NSNumber *primaryUsed = primary[@"usedPercent"];
    NSNumber *secondaryUsed = secondary[@"usedPercent"];
    self.usageView.primaryUsed = primaryUsed ? primaryUsed.doubleValue : -1;
    self.usageView.primaryRemaining = primaryUsed ? 100 - primaryUsed.doubleValue : -1;
    self.usageView.secondaryUsed = secondaryUsed ? secondaryUsed.doubleValue : -1;
    self.usageView.secondaryRemaining = secondaryUsed ? 100 - secondaryUsed.doubleValue : -1;
    self.usageView.primaryReset = [self formatEpoch:primary[@"resetsAt"]];
    self.usageView.secondaryReset = [self formatEpoch:secondary[@"resetsAt"]];
    NSString *plan = [bucket[@"planType"] isKindOfClass:[NSString class]] ? bucket[@"planType"] : @"-";
    NSString *credits = reset[@"availableCount"] ? [reset[@"availableCount"] description] : @"-";
    self.usageView.plan = plan;
    self.usageView.credits = credits;
    self.usageView.busy = self.busy;
    self.usageView.animationFrame = self.animationFrame;
    [self.usageView setNeedsDisplay:YES];
}

- (NSString *)formatEpoch:(NSNumber *)epoch {
    if (!epoch || epoch.doubleValue <= 0) {
        return @"-";
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"MMM d HH:mm";
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:epoch.doubleValue]];
}

- (void)startBundledServer {
    if (self.serverTask && self.serverTask.isRunning) {
        return;
    }

    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *serverDir = [resourcePath stringByAppendingPathComponent:@"status-server"];
    NSString *serverFile = [serverDir stringByAppendingPathComponent:@"server.js"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:serverFile]) {
        return;
    }

    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/env"];
    task.arguments = @[@"node", serverFile];
    task.currentDirectoryURL = [NSURL fileURLWithPath:serverDir];
    task.environment = @{
        @"PATH": @"/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/Applications/Codex.app/Contents/Resources",
        @"PORT": @"3333"
    };

    NSError *error = nil;
    if ([task launchAndReturnError:&error]) {
        self.serverTask = task;
    } else {
        self.statusItem.button.title = @" !";
        self.statusItem.button.image = [self pixelCatImageWithRemaining:0 busy:NO frame:0];
        [self updateMenuWithSnapshot:self.lastSnapshot error:@"无法启动本地 Node 服务"];
    }
}

- (void)updateBusy:(BOOL)isBusy {
    if (isBusy == self.busy) {
        return;
    }

    self.busy = isBusy;
    if (isBusy) {
        self.sawBusy = YES;
        self.usageView.busy = YES;
        [self startCatAnimation];
    } else {
        [self stopCatAnimation];
        self.usageView.busy = NO;
        self.usageView.animationFrame = 0;
        [self.usageView setNeedsDisplay:YES];
        if (self.sawBusy) {
            self.sawBusy = NO;
            [self notifyTaskCompleted];
        }
    }
}

- (void)startCatAnimation {
    if (self.animationTimer) {
        return;
    }
    self.animationTimer = [NSTimer timerWithTimeInterval:0.08 target:self selector:@selector(animateCat:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.animationTimer forMode:NSRunLoopCommonModes];
    [self animateCat:nil];
}

- (void)stopCatAnimation {
    [self.animationTimer invalidate];
    self.animationTimer = nil;
    self.animationFrame = 0;
    self.statusItem.button.image = [self pixelCatImageWithRemaining:self.lastRemaining busy:NO frame:0];
    self.statusItem.button.title = [NSString stringWithFormat:@" %.0f%%", self.lastRemaining];
    [self.statusItem.button setNeedsDisplay:YES];
}

- (void)animateCat:(NSTimer *)timer {
    self.animationFrame = (self.animationFrame + 1) % 42;
    self.statusItem.button.image = [self pixelCatImageWithRemaining:self.lastRemaining busy:YES frame:self.animationFrame];
    self.statusItem.button.title = [NSString stringWithFormat:@" %.0f%%", self.lastRemaining];
    [self.statusItem.button setNeedsDisplay:YES];
    self.usageView.busy = YES;
    self.usageView.animationFrame = self.animationFrame;
    [self.usageView setNeedsDisplay:YES];
}

- (void)notifyTaskCompleted {
    NSBeep();
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = @"Codex 任务完成";
    notification.informativeText = @"小猫休息啦，任务已经结束。";
    notification.soundName = NSUserNotificationDefaultSoundName;
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (NSColor *)colorForRemaining:(double)remaining {
    double t = MAX(0, MIN(100, remaining)) / 100.0;
    double r = (1.0 - t) * 0.92 + t * 0.16;
    double g = (1.0 - t) * 0.22 + t * 0.82;
    double b = (1.0 - t) * 0.18 + t * 0.36;
    return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0];
}

- (NSImage *)pixelCatImageWithRemaining:(double)remaining busy:(BOOL)busy frame:(NSInteger)frame {
    CGFloat scale = NSScreen.mainScreen.backingScaleFactor ?: 2.0;
    NSInteger logicalSize = 18;
    NSInteger pixelSize = logicalSize * scale;
    NSInteger unit = 2 * scale;
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(logicalSize, logicalSize)];

    [image lockFocus];
    [[NSColor clearColor] setFill];
    NSRectFill(NSMakeRect(0, 0, logicalSize, logicalSize));

    void (^block)(NSInteger, NSInteger, NSInteger, NSInteger, NSColor *) = ^(NSInteger x, NSInteger y, NSInteger w, NSInteger h, NSColor *color) {
        [color setFill];
        NSRectFill(NSMakeRect(x * unit / scale, y * unit / scale, w * unit / scale, h * unit / scale));
    };

    NSColor *ink = [self colorForRemaining:remaining];
    NSColor *accent = [NSColor colorWithCalibratedRed:0.97 green:0.96 blue:0.82 alpha:1.0];
    NSColor *eye = [NSColor colorWithCalibratedRed:0.08 green:0.10 blue:0.11 alpha:1.0];
    NSInteger bob = busy && (frame % 2 == 1) ? -1 : 0;
    NSInteger paw = busy ? frame % 2 : 0;
    NSArray<NSColor *> *rainbow = @[
        [NSColor colorWithCalibratedRed:1.00 green:0.28 blue:0.25 alpha:1.0],
        [NSColor colorWithCalibratedRed:1.00 green:0.62 blue:0.20 alpha:1.0],
        [NSColor colorWithCalibratedRed:0.98 green:0.86 blue:0.24 alpha:1.0],
        [NSColor colorWithCalibratedRed:0.26 green:0.86 blue:0.38 alpha:1.0],
        [NSColor colorWithCalibratedRed:0.25 green:0.74 blue:1.00 alpha:1.0],
        [NSColor colorWithCalibratedRed:0.58 green:0.42 blue:1.00 alpha:1.0],
    ];
    NSColor *(^catColor)(NSInteger) = ^NSColor *(NSInteger index) {
        if (!busy) return ink;
        return rainbow[(index + frame) % rainbow.count];
    };
    NSColor *spark = busy && (frame % 2 == 0) ? rainbow[(frame + 2) % rainbow.count] : ink;

    if (busy) {
        block(1, 1 + bob, 1, 2, catColor(0));
        block(6, 1 + bob, 1, 2, catColor(1));
        block(2, 2 + bob, 4, 1, catColor(2));
        block(1, 3 + bob, 6, 1, catColor(3));
        block(1, 4 + bob, 6, 1, catColor(4));
        block(1, 5 + bob, 6, 1, catColor(5));
        block(2, 6 + bob, 4, 1, catColor(0));
        block(2, 7 + paw, 1, 1, catColor(2));
        block(5, 8 - paw, 1, 1, catColor(4));
    } else {
        block(1, 1 + bob, 1, 2, ink);
        block(6, 1 + bob, 1, 2, ink);
        block(2, 2 + bob, 4, 1, ink);
        block(1, 3 + bob, 6, 3, ink);
        block(2, 6 + bob, 4, 1, ink);
        block(2, 7 + paw, 1, 1, ink);
        block(5, 8 - paw, 1, 1, ink);
    }
    block(2, 5 + bob, 4, 1, accent);
    block(3, 4 + bob, 1, 1, eye);
    block(5, 4 + bob, 1, 1, eye);
    block(4, 5 + bob, 1, 1, eye);
    block(0, 4 + bob, 1, 1, spark);
    block(7, 4 + bob, 1, 1, spark);

    [image unlockFocus];
    image.template = NO;
    image.size = NSMakeSize(logicalSize, logicalSize);
    (void)pixelSize;
    return image;
}

- (void)openDashboard:(id)sender {
    [self.statusItem.menu cancelTracking];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://127.0.0.1:3333"]];
}

- (void)quit:(id)sender {
    [self.statusItem.menu cancelTracking];
    [NSApp terminate:nil];
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
