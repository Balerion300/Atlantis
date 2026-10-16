#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
@interface NSObject (SpawnPuebloAPI)
- (id)initWithWorld:(id)prefs forCharacter:(NSString *)character withBasePath:(NSString *)path;
- (void)addCharacter:(NSString *)name;
- (void)setPreference:(id)value forKey:(NSString *)key withCharacter:(NSString *)character;
- (id)preferenceForKey:(NSString *)key;
- (void)handleData:(NSData *)data;
- (BOOL)commit;
+ (id)patternWithString:(NSString *)pattern type:(int)type;
- (id)initWithPath:(NSString *)path forPatterns:(NSArray *)patterns withExceptions:(NSArray *)exceptions weight:(unsigned)weight defaultsActive:(BOOL)active activePatterns:(NSArray *)activePatterns maxLines:(unsigned)lines prefix:(NSString *)prefix statusBar:(BOOL)status;
@end
static NSMutableArray *results,*sent;
static void Send(id self,SEL sel,NSString *text) { [sent addObject:text?:@""]; }
static NSString *Directory(void) { return NSProcessInfo.processInfo.environment[@"ATLANTIS_SPAWN_DIR"]; }
static void Feed(id world,NSString *text) { [world handleData:[text dataUsingEncoding:NSUTF8StringEncoding]]; }
static NSDictionary *Spawns(void) {
    id pattern=[NSClassFromString(@"RDStringPattern") patternWithString:@"<Staff>" type:0];
    id record=[[[NSClassFromString(@"RDSpawnConfigRecord") alloc] initWithPath:@"Staff" forPatterns:@[pattern] withExceptions:nil weight:1 defaultsActive:YES activePatterns:nil maxLines:1000 prefix:@"+staff" statusBar:YES] autorelease];
    return @{@"Staff":record};
}
static NSDictionary *Snapshot(id world) {
    NSMutableDictionary *text=[NSMutableDictionary dictionary];
    NSDictionary *spawns=[world valueForKey:@"_rdSpawns"];
    for(NSString *key in spawns) {
        NSTextView *view=[spawns[key] valueForKey:@"_rdOutputView"];
        [(id)view commit];
        text[key]=view.textStorage.string?:@"";
    }
    return text;
}
static id World(id prefs,NSString *character,NSString *path) {
    id world=[[NSClassFromString(@"RDAtlantisWorldInstance") alloc] initWithWorld:prefs forCharacter:character withBasePath:path];
    [world setValue:@(NSUTF8StringEncoding) forKey:@"_rdInputEncoding"];
    return world;
}
static id Prefs(NSString *name,BOOL enabled,BOOL spawns) {
    id prefs=[NSClassFromString(@"RDAtlantisWorldPreferences") new];
    [prefs setPreference:name forKey:@"atlantis.world.name" withCharacter:nil];
    [prefs setPreference:@(enabled) forKey:@"atlantis.pueblo.enabled" withCharacter:nil];
    [prefs setPreference:@NO forKey:@"atlantis.mxp.enabled" withCharacter:nil];
    [prefs setPreference:@YES forKey:@"atlantis.markup.commands" withCharacter:nil];
    [prefs addCharacter:@"One"];[prefs addCharacter:@"Two"];
    if(spawns) [prefs setPreference:Spawns() forKey:@"atlantis.spawns" withCharacter:@"One"];
    return prefs;
}
static NSString *Greeting=@"This world is Pueblo 1.10 Enhanced.\r\n</xch_mudtext><img xch_mode=purehtml>\r\n";
static NSString *Room=@"Room heading<BR>\r\n  Description &amp; details.<BR>\r\nContents: <a xch_cmd='look #123'>Test object</a><BR>\r\nObvious exits: <a xch_cmd='out'>Out</a><BR>\r\n&lt;Staff&gt; Test channel &amp; text.<BR>\r\n";
static void Run(void) {
    results=[NSMutableArray new];sent=[NSMutableArray new];
    @try {
        method_setImplementation(class_getInstanceMethod(NSClassFromString(@"RDAtlantisWorldInstance"),NSSelectorFromString(@"sendString:")),(IMP)Send);
        for(int mode=0;mode<3;mode++) for(int spawns=0;spawns<2;spawns++) {
            NSString *name=[NSString stringWithFormat:@"setting-%d-spawns-%d",mode,spawns];
            // 0: inherited on; 1: character on over world off; 2: character off over world on.
            id prefs=Prefs(name,mode!=1,spawns);
            if(mode) [prefs setPreference:@(mode==1) forKey:@"atlantis.pueblo.enabled" withCharacter:@"One"];
            id world=World(prefs,@"One",name);
            Feed(world,Greeting);Feed(world,Room);
            NSDictionary *before=Snapshot(world);
            // Updating spawn settings must preserve the negotiated parser state.
            [prefs setPreference:Spawns() forKey:@"atlantis.spawns" withCharacter:@"One"];
            Feed(world,@"After spawn update &amp; text.<BR>\r\n&lt;Staff&gt; Updated channel.<BR>\r\n");
            [results addObject:@{@"case":name,@"enabled":[world preferenceForKey:@"atlantis.pueblo.enabled"]?:@NO,@"before":before,@"afterSpawnUpdate":Snapshot(world)}];
        }
        // Same address book world, concurrent characters with opposite settings.
        id prefs=Prefs(@"simultaneous",YES,YES);
        [prefs setPreference:@NO forKey:@"atlantis.pueblo.enabled" withCharacter:@"Two"];
        id one=World(prefs,@"One",@"simultaneous-one"),two=World(prefs,@"Two",@"simultaneous-two");
        Feed(one,Greeting);Feed(two,Greeting);
        Feed(two,Room);Feed(one,Room);
        Feed(two,@"Two &amp; literal<BR>\r\n");Feed(one,@"One &amp; parsed<BR>\r\n");
        [results addObject:@{@"case":@"simultaneous-opposite-settings",@"enabledOne":[one preferenceForKey:@"atlantis.pueblo.enabled"],@"enabledTwo":[two preferenceForKey:@"atlantis.pueblo.enabled"],@"one":Snapshot(one),@"two":Snapshot(two)}];
        // Already-formatted server output without its initial mode declaration.
        id noMode=World(Prefs(@"no-mode",YES,YES),@"One",@"no-mode");
        Feed(noMode,@"This world is Pueblo 1.10 Enhanced.\r\n");Feed(noMode,Room);
        [results addObject:@{@"case":@"enabled-missing-server-mode",@"output":Snapshot(noMode)}];
    } @catch(NSException *e) { [results addObject:@{@"exception":e.name,@"reason":e.reason?:@""}]; }
    NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"results":results,@"capturedReplies":sent,@"gameConnections":@0} options:NSJSONWritingPrettyPrinted error:NULL];
    [data writeToFile:[Directory() stringByAppendingPathComponent:@"spawn-pueblo.json"] atomically:YES];
    exit(results.count==8?0:2);
}
__attribute__((constructor)) static void Begin(void) {
    if(!Directory()) return;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"SUEnableAutomaticChecks"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,4*NSEC_PER_SEC),dispatch_get_main_queue(),^{Run();});
}
