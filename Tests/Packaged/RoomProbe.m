#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

// Runs inside the downloaded release app. No Atlantis implementation is linked here.
@interface NSObject (AtlantisProbeAPI)
+ (id)controller;
- (id)initWithWorld:(id)world forCharacter:(NSString *)character withBasePath:(NSString *)path;
- (void)setPreference:(id)value forKey:(NSString *)key withCharacter:(NSString *)character;
- (void)connect;
- (void)filterInput:(id)input;
- (BOOL)isConnected;
- (void)disconnect;
- (void)sendString:(NSString *)text;
@end
static id currentWorld;
static NSMutableData *wire;
static NSMutableArray *sent;
static void (*originalData)(id,SEL,NSData *);
static void (*originalSend)(id,SEL,NSString *);
static void Capture(id self,SEL sel,NSData *data) {
    if (self==currentWorld && wire.length<1024*1024) [wire appendData:data];
    originalData(self,sel,data);
}
static void Send(id self,SEL sel,NSString *text) {
    if (self==currentWorld) {
        BOOL allowed=[@[@"connect Guest Guest",@"look",@"quit",@"PUEBLOCLIENT 1.10",@"think MAC_ROOM_ID=[num(me)] [loc(me)]",@"think MAC_ROOM_END=[num(me)] [loc(me)]"] containsObject:text];
        [sent addObject:@{@"command":text,@"allowed":@(allowed)}];
        if (!allowed) return;
    }
    originalSend(self,sel,text);
}
static NSString *Directory(void) { return NSProcessInfo.processInfo.environment[@"ATLANTIS_DIAGNOSTIC_DIR"]; }
static void Save(NSString *name,id doc) {
    NSData *data=[NSJSONSerialization dataWithJSONObject:doc options:NSJSONWritingPrettyPrinted error:NULL];
    [data writeToFile:[Directory() stringByAppendingPathComponent:name] atomically:YES];
}
static void Finish(int index,NSString *name,NSDate *start,BOOL sentLogin,BOOL sentLook) {
    @try {
        id spawn=[currentWorld valueForKey:@"_rdMainView"];
        NSTextView *view=[spawn valueForKey:@"_rdOutputView"];
        NSAttributedString *output=view.textStorage;
        __block NSUInteger links=0,images=0;
        [output enumerateAttributesInRange:NSMakeRange(0,output.length) options:0 usingBlock:^(NSDictionary *a,NSRange r,BOOL *stop){
            if (a[NSLinkAttributeName]) links++;
            if (a[NSAttachmentAttributeName]) images++;
        }];
        NSString *raw=[[[NSString alloc] initWithData:wire encoding:NSUTF8StringEncoding] autorelease];
        if (!raw) raw=[[[NSString alloc] initWithData:wire encoding:NSISOLatin1StringEncoding] autorelease];
        Save([name stringByAppendingString:@".json"],@{@"case":name,@"releasedExecutable":NSBundle.mainBundle.executablePath,@"connected":@([currentWorld isConnected]),@"loginSent":@(sentLogin),@"lookSent":@(sentLook),@"seconds":@(-start.timeIntervalSinceNow),@"wireBytes":@(wire.length),@"wireText":raw?:@"",@"output":output.string?:@"",@"links":@(links),@"images":@(images),@"sent":sent});
        [currentWorld disconnect];
    } @catch(NSException *e) { Save([name stringByAppendingString:@"-error.json"],@{@"exception":e.name,@"reason":e.reason?:@""}); }
}
static void RunCase(int index);
static void Tick(int index,NSString *name,NSDate *start,BOOL sentLogin,BOOL sentLook) {
    NSTimeInterval elapsed=-start.timeIntervalSinceNow;
    @try {
        if ([currentWorld isConnected] && elapsed>4 && !sentLogin) { [currentWorld sendString:@"connect Guest Guest"];sentLogin=YES; }
        if ([currentWorld isConnected] && elapsed>8 && sentLogin && !sentLook) { [currentWorld sendString:@"think MAC_ROOM_ID=[num(me)] [loc(me)]"];sentLook=YES; }
        if (elapsed>10 && ![[NSFileManager defaultManager] fileExistsAtPath:[Directory() stringByAppendingPathComponent:@"guest-ready.json"]]) {
            NSTextView *view=[[currentWorld valueForKey:@"_rdMainView"] valueForKey:@"_rdOutputView"];
            NSRegularExpression *pattern=[NSRegularExpression regularExpressionWithPattern:@"MAC_ROOM_ID=(#[0-9]+) (#[0-9]+)" options:0 error:NULL];
            NSTextCheckingResult *match=[pattern firstMatchInString:view.string options:0 range:NSMakeRange(0,view.string.length)];
            if (match) Save(@"guest-ready.json",@{@"guest_dbref":[view.string substringWithRange:[match rangeAtIndex:1]],@"initial_room":[view.string substringWithRange:[match rangeAtIndex:2]]});
        }
        if ((NSInteger)elapsed==75) [currentWorld sendString:@"look"];
        if ((NSInteger)elapsed==80) [currentWorld sendString:@"think MAC_ROOM_END=[num(me)] [loc(me)]"];
        if (elapsed>90) {
            Finish(index,name,start,sentLogin,sentLook);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{ RunCase(index+1); }); return;
        }
    } @catch(NSException *e) { Save([name stringByAppendingString:@"-tick-error.json"],@{@"exception":e.name,@"reason":e.reason?:@""});exit(2); }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{ Tick(index,name,start,sentLogin,sentLook); });
}
static void RunCase(int index) {
    NSArray *names=@[@"room-pueblo"];
    if (index>=names.count) { Save(@"complete.json",@{@"completed":@YES,@"cases":names});exit(0); }
    @try {
        id prefs=[[NSClassFromString(@"RDAtlantisWorldPreferences") alloc] init];
        NSDictionary *settings=@{@"atlantis.world.name":[@"Diagnostic " stringByAppendingString:names[index]],@"atlantis.world.host":@"bod.westeros.org",@"atlantis.world.port":@(index==2?3001:3000),@"atlantis.world.ssl":@(index==2),@"atlantis.world.codebase":@0,@"atlantis.pueblo.enabled":@YES,@"atlantis.mxp.enabled":@NO,@"atlantis.markup.images":@YES,@"atlantis.markup.commands":@YES,@"atlantis.formatting.font":[NSFont userFixedPitchFontOfSize:12]};
        for (NSString *key in settings) [prefs setPreference:settings[key] forKey:key withCharacter:nil];
        currentWorld=[[NSClassFromString(@"RDAtlantisWorldInstance") alloc] initWithWorld:prefs forCharacter:nil withBasePath:[@"Mac diagnostic/" stringByAppendingString:names[index]]];
        wire=[NSMutableData new];sent=[NSMutableArray new];
        NSMutableArray *filterChecks=[NSMutableArray new];
        for (id filter in [currentWorld valueForKey:@"_rdInputFilters"]) {
            if ([NSStringFromClass([filter class]) isEqualToString:@"RDMarkupFilter"] && index==0) {
                for (NSString *sample in @[@"Plain words and a line.\n",@"<Guest> Plain channel.\n"]) {
                    NSMutableAttributedString *input=[[[NSMutableAttributedString alloc] initWithString:sample] autorelease];
                    [filter filterInput:input];
                    [filterChecks addObject:@{@"input":sample,@"output":input.string}];
                }
            }
        }
        Save([names[index] stringByAppendingString:@"-filter-check.json"],filterChecks);
        [currentWorld connect];
        Tick(index,names[index],[NSDate date],NO,NO);
    } @catch(NSException *e) { Save(@"startup-error.json",@{@"exception":e.name,@"reason":e.reason?:@""});exit(2); }
}
__attribute__((constructor)) static void Begin(void) {
    if (!Directory()) return;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"SUEnableAutomaticChecks"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        @try {
            Class world=NSClassFromString(@"RDAtlantisWorldInstance");
            Method receive=class_getInstanceMethod(world,NSSelectorFromString(@"handleData:"));
            Method send=class_getInstanceMethod(world,@selector(sendString:));
            if (!receive || !send) { Save(@"load-error.json",@{@"error":@"Released app runtime classes unavailable"});exit(2); }
            originalData=(void *)method_setImplementation(receive,(IMP)Capture);
            originalSend=(void *)method_setImplementation(send,(IMP)Send);
            RunCase(0);
        } @catch(NSException *e) { Save(@"load-error.json",@{@"exception":e.name,@"reason":e.reason?:@""});exit(2); }
    });
}
