#import <Cocoa/Cocoa.h>

// Injected into the actual packaged app; no game connections or commands.
@interface NSObject (ScrollProbeAPI)
- (id)initWithWorld:(id)world forCharacter:(NSString *)character withBasePath:(NSString *)path;
- (void)setPreference:(id)value forKey:(NSString *)key withCharacter:(NSString *)character;
- (void)appendString:(NSAttributedString *)string;
- (BOOL)commit;
- (BOOL)autoScroll;
- (void)setAutoScroll:(BOOL)value;
- (void)performScrollToEnd;
- (void)refreshMarkupAttachment:(NSTextAttachment *)attachment;
@end
static id spawn;
static NSTextView *view;
static NSScrollView *scroll;
static NSWindow *window;
static NSMutableArray *results;
static NSString *Directory(void) { return NSProcessInfo.processInfo.environment[@"ATLANTIS_SCROLL_DIR"]; }
static CGFloat Gap(void) {
    [view.layoutManager ensureLayoutForTextContainer:view.textContainer];
    return MAX(0,NSMaxY(view.bounds)-NSMaxY(scroll.documentVisibleRect));
}
static void Save(void) {
    NSData *data=[NSJSONSerialization dataWithJSONObject:results options:NSJSONWritingPrettyPrinted error:NULL];
    [data writeToFile:[Directory() stringByAppendingPathComponent:@"scroll.json"] atomically:YES];
}
static void RunCase(int index) {
    if (index==3) { Save();exit(0); }
    @try {
        [view.textStorage setAttributedString:[[[NSAttributedString alloc] initWithString:@""] autorelease]];
        NSTextAttachment *attachment=[[[NSTextAttachment alloc] init] autorelease];
        [attachment setAttachmentCell:[[[NSTextAttachmentCell alloc] initTextCell:@"[room image: loading]"] autorelease]];
        NSMutableAttributedString *text=[[[NSMutableAttributedString alloc] initWithString:@"Room heading\n"] autorelease];
        [text appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
        NSMutableString *description=[NSMutableString stringWithString:@"\n"];
        for(int n=0;n<35;n++) [description appendFormat:@"Room description line %d\n",n];
        [description appendString:@"Contents: Test object\nObvious exits: Out\n"];
        [text appendAttributedString:[[[NSAttributedString alloc] initWithString:description] autorelease]];
        [text addAttribute:NSFontAttributeName value:[NSFont userFixedPitchFontOfSize:12] range:NSMakeRange(0,text.length)];
        [[scroll verticalScroller] setAutoScroll:YES];
        [(id)view appendString:text];[(id)view commit];
        [view.layoutManager ensureLayoutForTextContainer:view.textContainer];
        [(id)view performScrollToEnd];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
            CGFloat initialGap=Gap();
            if(index==1) {
                [scroll.contentView scrollToPoint:NSMakePoint(0,80)];
                [scroll reflectScrolledClipView:scroll.contentView];
                [[scroll verticalScroller] setAutoScroll:NO];
            }
            CGFloat before=scroll.documentVisibleRect.origin.y;
            NSImage *image=[[[NSImage alloc] initWithSize:NSMakeSize(280,320)] autorelease];
            [attachment setAttachmentCell:[[[NSTextAttachmentCell alloc] initImageCell:image] autorelease]];
            if(index==2) {
                // An attachment trimmed out of scrollback must have no effect.
                NSTextAttachment *absent=[[[NSTextAttachment alloc] init] autorelease];
                [spawn refreshMarkupAttachment:absent];
            } else [spawn refreshMarkupAttachment:attachment];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,300*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                CGFloat gap=Gap(),after=scroll.documentVisibleRect.origin.y;
                [results addObject:@{@"case":@[@"following-image-growth",@"reading-scrollback",@"absent-attachment"][index],@"initialGap":@(initialGap),@"gap":@(gap),@"beforeY":@(before),@"afterY":@(after),@"following":@([(id)scroll autoScroll])}];
                RunCase(index+1);
            });
        });
    } @catch(NSException *e) { [results addObject:@{@"exception":e.name,@"reason":e.reason?:@""}];Save();exit(2); }
}
__attribute__((constructor)) static void Begin(void) {
    if(!Directory()) return;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"SUEnableAutomaticChecks"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,4*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        @try {
            results=[NSMutableArray new];
            id prefs=[[NSClassFromString(@"RDAtlantisWorldPreferences") alloc] init];
            [prefs setPreference:@"Offline scroll check" forKey:@"atlantis.world.name" withCharacter:nil];
            id world=[[NSClassFromString(@"RDAtlantisWorldInstance") alloc] initWithWorld:prefs forCharacter:nil withBasePath:@"Offline scroll check"];
            spawn=[world valueForKey:@"_rdMainView"];
            view=[spawn valueForKey:@"_rdOutputView"];
            scroll=[view enclosingScrollView];
            [scroll retain];[scroll removeFromSuperview];
            window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,620,220) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
            [window setContentView:scroll];[scroll release];[window orderFront:nil];
            RunCase(0);
        } @catch(NSException *e) { results=[NSMutableArray arrayWithObject:@{@"exception":e.name,@"reason":e.reason?:@""}];Save();exit(2); }
    });
}
