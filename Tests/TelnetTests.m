#import "RDTelnetFilter.h"
static void Check(BOOL pass,NSString *name) { if (!pass) { NSLog(@"FAIL: %@",name); exit(1); } }
@implementation RDAtlantisWorldInstance
- (id)init { if ((self=[super init])) { sent=[NSMutableData new]; [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mxpChanged:) name:@"RDAtlantisMXPChanged" object:self]; } return self; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [sent release]; [super dealloc]; }
- (id)preferenceForKey:(NSString *)key { return [key isEqualToString:@"atlantis.mxp.enabled"] ? @(mxp) : @0; }
- (void)sendDataRaw:(NSData *)data { [sent appendData:data]; }
- (void)mxpChanged:(NSNotification *)note { active=[note.userInfo[@"enabled"] boolValue]; if (active) starts++; }
- (int)mainScreenWidth { return 80; } - (int)mainScreenHeight { return 25; }
- (NSStringEncoding)stringEncoding { return NSUTF8StringEncoding; }
- (void)setStringEncoding:(NSStringEncoding)encoding {} - (void)handleStatusOutput:(NSString *)text {} - (void)compress:(BOOL)enabled {} - (void)addBytesToCompress:(NSData *)data {}
@end
static NSMutableData *Feed(RDTelnetFilter *filter,const unsigned char *bytes,NSUInteger n) { NSMutableData *data=[NSMutableData dataWithBytes:bytes length:n]; [filter filterInput:data]; return data; }
int main(void) { @autoreleasepool {
    const unsigned char will[]={255,251,91}, start[]={255,250,91,255,240}, wont[]={255,252,91};
    const unsigned char dont[]={255,254,91}, accept[]={255,253,91};
    RDAtlantisWorldInstance *world=[RDAtlantisWorldInstance new]; RDTelnetFilter *filter=[[RDTelnetFilter alloc] initWithWorld:world];
    Feed(filter,will,3); Check([world->sent isEqualToData:[NSData dataWithBytes:dont length:3]],@"disabled refuses MXP"); [filter release]; [world release];
    for (NSUInteger split=1;split<3;split++) {
        world=[RDAtlantisWorldInstance new]; world->mxp=YES; filter=[[RDTelnetFilter alloc] initWithWorld:world];
        Feed(filter,will,split); Feed(filter,will+split,3-split);
        Check([world->sent isEqualToData:[NSData dataWithBytes:accept length:3]],@"fragmented WILL accepted");
        for (NSUInteger i=0;i<5;i++) Feed(filter,start+i,1);
        Check(world->active && world->starts==1,@"one-byte fragmented start");
        Feed(filter,wont,3); Check(!world->active && [world->sent subdataWithRange:NSMakeRange(3,3)].length==3,@"WONT disables MXP");
        const unsigned char plain[]={'h','e','l','l','o','\n'};
        Check([Feed(filter,plain,6) isEqualToData:[NSData dataWithBytes:plain length:6]],@"plain Telnet unchanged");
        const unsigned char raw[]={'a',255,'b'}, escaped[]={'a',255,255,'b'}; NSMutableData *data=[NSMutableData dataWithBytes:raw length:3]; [filter filterOutput:data];
        Check([data isEqualToData:[NSData dataWithBytes:escaped length:4]],@"literal IAC safely escaped");
        [filter release]; [world release];
    }
    printf("PASS: MXP negotiation, fragmented packets, plain Telnet and IAC escaping\n");
} return 0; }
