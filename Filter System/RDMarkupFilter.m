#import "RDMarkupFilter.h"
#import "RDAtlantisSpawn.h"
@implementation RDMarkupFilter
- (id)initWithWorld:(RDAtlantisWorldInstance *)world {
    if ((self=[super initWithWorld:world])) {
        _parser=[RDMarkupParser new]; _parser.delegate=self; _commands=[NSMutableDictionary new];
        [self worldWasRefreshed];
        for (NSString *name in @[@"RDAtlantisConnectionDidConnectNotification",@"RDAtlantisConnectionDidDisconnectNotification"])
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionChanged:) name:name object:world];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mxpChanged:) name:@"RDAtlantisMXPChanged" object:world];
    } return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; _parser.delegate=nil; [_loader shutdown]; [_loader release]; [_parser release]; [_commands release]; [super dealloc]; }
- (void)connectionChanged:(NSNotification *)note { [_parser reset]; [_commands removeAllObjects]; [_loader shutdown]; [_loader release]; _loader=nil; }
- (void)mxpChanged:(NSNotification *)note { [_parser activateMXP:[note.userInfo[@"enabled"] boolValue]]; }
- (void)worldWasRefreshed {
    [_parser configurePueblo:[[[self world] preferenceForKey:@"atlantis.pueblo.enabled"] boolValue] mxp:[[[self world] preferenceForKey:@"atlantis.mxp.enabled"] boolValue]];
    [_commands removeAllObjects]; [_loader shutdown]; [_loader release]; _loader=nil;
}
- (void)filterInput:(id)input { if ([input isKindOfClass:NSMutableAttributedString.class]) [(NSMutableAttributedString *)input setAttributedString:[_parser consume:input]]; }
- (void)markupReply:(NSString *)reply { [[self world] sendString:[reply stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet]]; }
- (NSURL *)markupCommand:(NSString *)command {
    id setting=[[self world] preferenceForKey:@"atlantis.markup.commands"];
    if ((setting && ![setting boolValue]) || !command.length || command.length>4000 || [command rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound || _commands.count>=4096) return nil;
    // Multi-command MXP menus are not supported: keep their first explicit command.
    command=[command componentsSeparatedByString:@"|"][0];
    NSString *key=NSUUID.UUID.UUIDString; _commands[key]=command;
    return [NSURL URLWithString:[@"atlantis-command:" stringByAppendingString:key]];
}
- (BOOL)activateLink:(NSURL *)url {
    if (![url.scheme isEqualToString:@"atlantis-command"]) return NO;
    NSString *command=_commands[url.resourceSpecifier]; id enabled=[[self world] preferenceForKey:@"atlantis.markup.commands"];
    if (command && [[self world] isConnected] && (!enabled || [enabled boolValue])) [[self world] sendString:command];
    return YES;
}
- (NSAttributedString *)markupImage:(NSURL *)url alternate:(NSString *)alternate {
    if (alternate.length>200) alternate=[alternate substringToIndex:200];
    if (!url || ![[[self world] preferenceForKey:@"atlantis.markup.images"] boolValue]) return [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"[%@]",alternate]] autorelease];
    if (!_loader) { _loader=[RDMarkupImageLoader new]; _loader.delegate=self; }
    return [_loader image:url alternate:alternate];
}
- (void)markupAttachmentChanged:(NSTextAttachment *)attachment {
    NSEnumerator *spawns=[[self world] spawnEnumerator]; RDAtlantisSpawn *spawn;
    while ((spawn=[spawns nextObject])) [spawn refreshMarkupAttachment:attachment];
}
@end
