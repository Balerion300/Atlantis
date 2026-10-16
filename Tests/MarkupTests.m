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

static void CheckPuebloSplits(TestDelegate *delegate,NSString *sample,NSString *expected,NSString *name) {
    RDMarkupParser *parser=[RDMarkupParser new]; parser.delegate=delegate;
    [parser configurePueblo:YES mxp:NO]; BOOL valid=YES;
    for (NSUInteger split=0;split<=sample.length;split++) {
        [parser reset]; [parser consume:Text(@"<img xch_mode=purehtml>")];
        NSMutableString *actual=[NSMutableString stringWithString:[parser consume:Text([sample substringToIndex:split])].string];
        [actual appendString:[parser consume:Text([sample substringFromIndex:split])].string];
        if (![actual isEqualToString:expected]) { NSLog(@"%@ split=%lu actual=%@",name,(unsigned long)split,actual); valid=NO; break; }
    }
    Check(valid,[name stringByAppendingString:@" at every network split"]);
    [parser reset]; [parser consume:Text(@"<img xch_mode=purehtml>")];
    NSMutableString *actual=[NSMutableString string];
    for (NSUInteger i=0;i<sample.length;i++) [actual appendString:[parser consume:Text([sample substringWithRange:NSMakeRange(i,1)])].string];
    Check([actual isEqualToString:expected],[name stringByAppendingString:@" byte by byte"]);
    parser.delegate=nil; [parser release];
}

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
        Check([[p consume:Text(@"</xch_mudtext>")].string isEqualToString:@""],@"PennMUSH initial literal-mode closing tag is a control");
        [p consume:Text(@"<img xch_mode=pu")];
        NSAttributedString *out=[p consume:Text(@"rehtml><b>Bold</b> &amp; <a xch_cmd='look' xch_hint='Look'>Room</a><img src='https://example.com/a.png' alt='Castle'>")];
        Check([out.string isEqualToString:@"Bold & Room[Castle]"],@"fragmented Pueblo controls and entities");
        Check([out attribute:NSLinkAttributeName atIndex:7 effectiveRange:NULL]!=nil && d->commands.count==1,@"clickable Pueblo command metadata, no execution");
        Check(d->images==1,@"inline image URL extracted");
        Check([[p consume:Text(@"<IMG XCH_GRAPH=HIDE><IMG XCH_GRAPH=SHOW>")].string isEqualToString:@""],@"Pueblo graphics controls do not display phantom images");
        Check(d->images==1,@"graphics controls do not request downloads");
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
        for (NSString *ending in @[@"\n",@"\r\n",@"\r"]) {
            NSString *sample=[NSString stringWithFormat:@"<pre>Player Name   Loc #<BR>%@Jon           #4447<BR>%@Nerys         #4445<BR>%@</pre>",ending,ending,ending];
            CheckPuebloSplits(d,sample,@"Player Name   Loc #\nJon           #4447\nNerys         #4445\n",@"Pueblo WHO line endings");
        }
        CheckPuebloSplits(d,@"<pre>A<BR>\n\nB<BR><BR>\nC\n\nD<BR>  E</pre>",@"A\n\nB\n\nC\n\nD\n  E\n",@"intentional PRE blank lines and column spaces");
        CheckPuebloSplits(d,@"<div>Room<BR>\n</div><pre>    Description<BR>\n\n    Weather<BR>\n</pre>Contents:<BR>\nPlayer<BR>\n",@"Room\n    Description\n\n    Weather\nContents:\nPlayer\n",@"room paragraphs do not add redundant block breaks");
        CheckPuebloSplits(d,@"<pre><a xch_cmd='look'><img src='https://example.com/a.png' alt='Castle'></a><BR>\nCaption<BR>\n</pre>",@"[Castle]\nCaption\n",@"inline image and caption spacing");
        [p configurePueblo:YES mxp:NO]; [p consume:Text(@"<img xch_mode=purehtml><pre>A<BR>")];
        [p reset]; [p consume:Text(@"<img xch_mode=purehtml>")];
        Check([[p consume:Text(@"<pre>\nB</pre>")].string isEqualToString:@"\nB\n"],@"reconnect clears pending Pueblo wire ending");
        [p consume:Text(@"<BR>")];
        Check([[p consume:Text(@"<xch_mudtext>\nLiteral</xch_mudtext>")].string isEqualToString:@"\nLiteral"],@"mode switch preserves literal newline");
        [p configurePueblo:NO mxp:YES]; [p activateMXP:YES];
        Check([[p consume:Text(@"\033[1zOne<BR>\nTwo")].string isEqualToString:@"One\n\nTwo"],@"MXP raw newline semantics unchanged");
        RDMarkupParser *recovery=[RDMarkupParser new]; TestDelegate *rd=[TestDelegate new]; recovery.delegate=rd;
        [recovery configurePueblo:YES mxp:NO];
        Check([[recovery consume:Text(@"<Staff> literal &amp; text<BR>\n")].string isEqualToString:@"<Staff> literal &amp; text<BR>\n"],@"recovery requires a Pueblo greeting");
        [recovery consume:Text(@"This world is Pueblo 1.10 Enhanced.\n")];
        Check([[recovery consume:Text(@"<a xch_cmd='look'>Example</a><img src='https://example.com/a.png'>")].string containsString:@"xch_cmd"] && rd->commands.count==0 && rd->images==0,@"links and images alone cannot trigger recovery");
        out=[recovery consume:Text(@"&lt;Staff&gt; One &amp; two<BR>\n")];
        Check([out.string isEqualToString:@"<Staff> One & two\n"],@"missing Pueblo mode recovers on a complete line-ending break");
        Check([[recovery consume:Text(@"<Staff> Ordinary <someone> labels\n")].string isEqualToString:@"<Staff> Ordinary <someone> labels\n"],@"recovery preserves unknown angle-bracket labels");
        out=[recovery consume:Text(@"<a xch_cmd='look'>Room</a><BR>\n")];
        Check([out.string isEqualToString:@"Room\n"] && [out attribute:NSLinkAttributeName atIndex:0 effectiveRange:NULL]!=nil && rd->commands.count==1,@"recovered links retain click-only metadata");
        [recovery reset];[recovery consume:Text(@"This world is Pueblo 1.10 Enhanced.\n")];
        NSMutableString *splitRecovery=[NSMutableString stringWithString:[recovery consume:Text(@"Room<B")].string];
        [splitRecovery appendString:[recovery consume:Text(@"R>\nNext &amp; line<BR>\n")].string];
        Check([splitRecovery isEqualToString:@"Room\nNext & line\n"],@"fragmented recovery break completes without leaking a tag");
        [recovery reset];[recovery consume:Text(@"This world is Pueblo 1.10 Enhanced.\n<xch_mudtext>")];
        Check([[recovery consume:Text(@"Code &amp; text<BR>\n")].string isEqualToString:@"Code &amp; text<BR>\n"],@"explicit literal mode prevents recovery even without XCH_MODE");
        Check([[recovery consume:Text(@"</xch_mudtext>&lt;Staff&gt; Back<BR>\n")].string isEqualToString:@"<Staff> Back\n"],@"explicit closing literal mode restores HTML without XCH_MODE");
        [recovery reset];[recovery consume:Text(@"This world is Pueblo 1.10 Enhanced.\n<img xch_mode=text>")];
        Check([[recovery consume:Text(@"Literal<BR>\n")].string isEqualToString:@"Literal<BR>\n"],@"explicit text mode is not overridden by recovery");
        [recovery reset];
        Check([[recovery consume:Text(@"&lt;Staff&gt; Reconnect<BR>\n")].string isEqualToString:@"&lt;Staff&gt; Reconnect<BR>\n"],@"reconnect discards permission to recover");
        [recovery configurePueblo:NO mxp:NO];
        Check([[recovery consume:Text(@"This world is Pueblo 1.10 Enhanced.\nCode<BR>\n")].string containsString:@"Code<BR>"],@"disabled Pueblo remains literal despite greeting and break");
        [recovery configurePueblo:YES mxp:YES];[recovery activateMXP:YES];
        [recovery consume:Text(@"This world is Pueblo 1.10 Enhanced.\n")];
        Check([[recovery consume:Text(@"\033[1zMXP<BR>\n")].string isEqualToString:@"MXP\n\n"] && ![[recovery valueForKey:@"_puebloActive"] boolValue],@"recovery never takes over an active MXP session");
        recovery.delegate=nil;[recovery release];[rd release];
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
