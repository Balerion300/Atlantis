#import <Cocoa/Cocoa.h>
#import "RDMarkupParser.h"
#import "RDMarkupImageLoader.h"

static NSUInteger checks=0;
static void Check(BOOL pass,NSString *name) { checks++; if (!pass) { NSLog(@"FAIL: %@",name); exit(1); } }
static NSAttributedString *Text(NSString *s) { return [[[NSAttributedString alloc] initWithString:s attributes:@{NSForegroundColorAttributeName:NSColor.cyanColor}] autorelease]; }
@interface TestDelegate : NSObject <RDMarkupDelegate,RDMarkupImageDelegate> {
@public NSMutableArray *replies, *commands; NSUInteger images, changed;
}
- (void)stopRunLoop;
@end
@implementation TestDelegate
- (id)init { if ((self=[super init])) { replies=[NSMutableArray new]; commands=[NSMutableArray new]; } return self; }
- (void)dealloc { [replies release]; [commands release]; [super dealloc]; }
- (void)markupReply:(NSString *)reply { [replies addObject:reply]; }
- (NSURL *)markupCommand:(NSString *)command { [commands addObject:command]; return [NSURL URLWithString:@"atlantis-command:test"]; }
- (NSAttributedString *)markupImage:(NSURL *)url alternate:(NSString *)alternate { if (url) images++; return Text([NSString stringWithFormat:@"[%@]",alternate]); }
- (void)stopRunLoop {
    [NSApp stop:nil];
    [NSApp postEvent:[NSEvent otherEventWithType:NSEventTypeApplicationDefined location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil subtype:0 data1:0 data2:0] atStart:NO];
}
- (void)markupAttachmentChanged:(NSTextAttachment *)attachment { changed++; [self stopRunLoop]; }
@end

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp finishLaunching];
        TestDelegate *d=[TestDelegate new]; RDMarkupParser *p=[RDMarkupParser new]; p.delegate=d;
        Check([[p consume:Text(@"<b>literal</b>\n")].string isEqualToString:@"<b>literal</b>\n"],@"disabled plain Telnet");
        [p configurePueblo:YES mxp:NO];
        Check([[p consume:Text(@"<Staff> Hello\n")].string isEqualToString:@"<Staff> Hello\n"],@"channel markers before activation");
        [p consume:Text(@"This world is Pueblo 1.")]; [p consume:Text(@"10 Enhanced.\n")]; [p consume:Text(@"This world is Pueblo 1.10 Enhanced.\n")];
        Check(d->replies.count==1 && [d->replies[0] isEqualToString:@"PUEBLOCLIENT 1.10\n"],@"fragmented greeting replies once");
        [p consume:Text(@"<img xch_mode=pu")];
        NSAttributedString *out=[p consume:Text(@"rehtml><b>Bold</b> &amp; <a xch_cmd='look' xch_hint='Look'>Room</a><img src='https://example.com/a.png' alt='Castle'>")];
        Check([out.string isEqualToString:@"Bold & Room[Castle]"],@"fragmented Pueblo controls and entities");
        Check([out attribute:NSLinkAttributeName atIndex:7 effectiveRange:NULL]!=nil && d->commands.count==1,@"clickable Pueblo command metadata, no execution");
        Check(d->images==1,@"inline image URL extracted");
        Check([[out attribute:NSForegroundColorAttributeName atIndex:7 effectiveRange:NULL] isEqual:NSColor.cyanColor],@"ANSI attributes retained");
        Check([[p consume:Text(@"<xch_mudtext><Public> &amp;</xch_mudtext>&lt;")].string isEqualToString:@"<Public> &amp;<"],@"Pueblo literal text mode");
        Check([[p consume:Text(@"<script><b>bad</b></script>safe")].string isEqualToString:@"safe"],@"hidden executable content");
        Check([RDMarkupParser safeURL:@"file:///etc/passwd"]==nil && [RDMarkupParser safeURL:@"javascript:alert(1)"]==nil && [RDMarkupParser safeURL:@"https://user:secret@example.com/a"]==nil,@"unsafe schemes and credentials rejected");
        Check([[p consume:Text(@"&#x1f409;")].string isEqualToString:@"🐉"],@"Unicode numeric entity");
        [p reset]; Check([[p consume:Text(@"<b>literal</b>")].string isEqualToString:@"<b>literal</b>"],@"reconnect resets display mode");
        [p configurePueblo:NO mxp:YES];
        Check([[p consume:Text(@"\033[1z<send href='look'>Room</send>")].string isEqualToString:@"<send href='look'>Room</send>"],@"MXP needs negotiation");
        [p activateMXP:YES]; NSUInteger count=d->commands.count;
        Check([[p consume:Text(@"<send href='look'>Room</send>\n")].string isEqualToString:@"<send href='look'>Room</send>\n"] && d->commands.count==count,@"secure tags rejected in open MXP");
        out=[p consume:Text(@"\033[1z<send href='look'>Room</send>\n")];
        Check([out.string isEqualToString:@"Room\n"] && [out attribute:NSLinkAttributeName atIndex:0 effectiveRange:NULL]!=nil,@"secure MXP send link");
        Check([[p consume:Text(@"\033[2z<b>literal</b>\n<b>open</b>")].string isEqualToString:@"<b>literal</b>\nopen"],@"locked line resets to open at newline");
        Check([[p consume:Text(@"\033[7z<b>literal</b>\n<b>also literal</b>\033[3z<b>ok</b>")].string isEqualToString:@"<b>literal</b>\n<b>also literal</b>ok"],@"locked default and reset");
        out=[p consume:Text(@"<u>one\ntwo")]; Check([out attribute:NSUnderlineStyleAttributeName atIndex:4 effectiveRange:NULL]==nil,@"open tags close on newline");
        [p consume:Text(@"\033[1z<version><support>\n")]; Check(d->replies.count==3,@"MXP version and supported subset replies");
        [p consume:Text(@"\033[1z<support send.href send.prompt element>\n")];
        Check([d->replies.lastObject containsString:@"+send.href -send.prompt -element"],@"unsupported attributes reported truthfully");
        count=d->commands.count;
        out=[p consume:Text(@"\033[1z<send href='look' prompt>Room</send><send href='one|two'>Menu</send>\n")];
        Check(d->commands.count==count && [out attribute:NSLinkAttributeName atIndex:0 effectiveRange:NULL]==nil,@"unsupported SEND variants never send a different command");
        [p consume:Text(@"\033[4z ordinary text <send href='look'>Room</send>\n")];
        Check(d->commands.count==count,@"temporary secure mode must immediately precede tag");
        Check([[p consume:Text(@"\033[1z<image fname='a.png' url='https://example.com/' alt='Rock'>\n")].string isEqualToString:@"[Rock]\n"] && d->images==2,@"MXP image base URL");
        NSMutableString *huge=[NSMutableString stringWithString:@"<"]; for (int i=0;i<4200;i++) [huge appendString:@"x"];
        Check([p consume:Text(huge)].length>=4096,@"unterminated token bounded");
        [p activateMXP:NO];
        RDMarkupImageLoader *loader=[RDMarkupImageLoader new]; loader.delegate=d;
        NSAttributedString *image=[loader image:[NSURL URLWithString:@"http://127.0.0.1:8935/image.png"] alternate:@"Fixture"];
        NSTextAttachment *attachment=[image attribute:NSAttachmentAttributeName atIndex:0 effectiveRange:NULL];
        NSTimer *timeout=[NSTimer scheduledTimerWithTimeInterval:8 target:d selector:@selector(stopRunLoop) userInfo:nil repeats:NO];
        [NSApp run]; [timeout invalidate];
        if (d->changed!=1 || ![(NSCell *)attachment.attachmentCell image]) NSLog(@"Image fixture: callbacks=%lu cell=%@",(unsigned long)d->changed,[(NSCell *)attachment.attachmentCell stringValue]);
        Check(d->changed==1 && [(NSCell *)attachment.attachmentCell image]!=nil,@"asynchronous inline image attachment load");
        [loader shutdown]; [loader release]; p.delegate=nil; [p release]; [d release];
        printf("PASS: %lu focused markup checks\n",(unsigned long)checks);
    }
    return 0;
}
