#import "RDMarkupParser.h"

static NSString *RDEntity(NSString *name) {
    NSDictionary *names = @{ @"lt":@"<", @"gt":@">", @"amp":@"&", @"quot":@"\"", @"apos":@"'", @"nbsp":@"\u00a0" };
    NSString *known = names[name];
    if (known) return known;
    if (![name hasPrefix:@"#"]) return nil;
    NSString *digits = [name substringFromIndex:1];
    unsigned value = 0;
    NSScanner *scanner;
    if ([digits hasPrefix:@"x"] || [digits hasPrefix:@"X"]) {
        scanner = [NSScanner scannerWithString:[digits substringFromIndex:1]];
        if (![scanner scanHexInt:&value] || ![scanner isAtEnd]) return nil;
    } else {
        scanner = [NSScanner scannerWithString:digits];
        int decimal;
        if (![scanner scanInt:&decimal] || ![scanner isAtEnd] || decimal < 0) return nil;
        value = (unsigned)decimal;
    }
    if (value < 32 || (value >= 0x7f && value <= 0x9f) || value > 0x10ffff || (value >= 0xd800 && value <= 0xdfff)) return nil;
    if (value <= 0xffff) { unichar c = value; return [NSString stringWithCharacters:&c length:1]; }
    value -= 0x10000;
    unichar pair[] = { 0xd800 + (value >> 10), 0xdc00 + (value & 0x3ff) };
    return [NSString stringWithCharacters:pair length:2];
}

static NSString *RDDecode(NSString *text) {
    NSMutableString *result = [NSMutableString string];
    NSUInteger i = 0;
    while (i < text.length) {
        if ([text characterAtIndex:i] == '&') {
            NSRange end = [text rangeOfString:@";" options:0 range:NSMakeRange(i, MIN(40,text.length-i))];
            if (end.location != NSNotFound) {
                NSString *entity = RDEntity([text substringWithRange:NSMakeRange(i+1,end.location-i-1)]);
                if (entity) { [result appendString:entity]; i = NSMaxRange(end); continue; }
            }
        }
        [result appendString:[text substringWithRange:NSMakeRange(i++,1)]];
    }
    return result;
}

static NSColor *RDColor(NSString *name) {
    if (!name.length) return nil;
    name = [name lowercaseString];
    if ([name hasPrefix:@"#"] && (name.length == 7 || name.length == 4)) {
        unsigned n; NSScanner *s = [NSScanner scannerWithString:[name substringFromIndex:1]];
        if (![s scanHexInt:&n] || !s.isAtEnd) return nil;
        if (name.length == 4) n = ((n & 0xf00) << 12) | ((n & 0xf00) << 8) | ((n & 0xf0) << 8) | ((n & 0xf0) << 4) | ((n & 0xf) << 4) | (n & 0xf);
        return [NSColor colorWithCalibratedRed:((n>>16)&255)/255.0 green:((n>>8)&255)/255.0 blue:(n&255)/255.0 alpha:1];
    }
    return @{ @"red":NSColor.redColor, @"green":NSColor.greenColor, @"blue":NSColor.blueColor,
              @"white":NSColor.whiteColor, @"black":NSColor.blackColor, @"yellow":NSColor.yellowColor,
              @"cyan":NSColor.cyanColor, @"magenta":NSColor.magentaColor, @"gray":NSColor.grayColor,
              @"grey":NSColor.grayColor, @"orange":NSColor.orangeColor }[name];
}

// Attribute values may be quoted and contain >. Positional MXP arguments are retained.
static NSDictionary *RDTag(NSString *token) {
    NSString *body = [token substringWithRange:NSMakeRange(1,token.length-2)];
    NSScanner *s = [NSScanner scannerWithString:body];
    NSCharacterSet *ws = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    s.charactersToBeSkipped = ws;
    NSString *name = nil;
    [s scanUpToCharactersFromSet:ws intoString:&name];
    if (!name) return @{};
    NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithObject:[name.lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]] forKey:@"tag"];
    attrs[@"closing"] = @([body hasPrefix:@"/"]);
    attrs[@"empty"] = @([body hasSuffix:@"/"]);
    NSMutableArray *positional = [NSMutableArray array];
    while (!s.isAtEnd) {
        [s scanCharactersFromSet:ws intoString:NULL];
        if (s.isAtEnd) break;
        NSString *key = nil, *value = nil;
        unichar c = [body characterAtIndex:s.scanLocation];
        if (c == '\'' || c == '"') {
            NSString *quote = [NSString stringWithFormat:@"%C",c]; s.scanLocation++;
            [s scanUpToString:quote intoString:&value]; [s scanString:quote intoString:NULL];
            [positional addObject:RDDecode(value ?: @"")]; continue;
        }
        [s scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"= \t\r\n/"] intoString:&key];
        if (!key) { s.scanLocation++; continue; }
        [s scanCharactersFromSet:ws intoString:NULL];
        if ([s scanString:@"=" intoString:NULL]) {
            [s scanCharactersFromSet:ws intoString:NULL];
            if (!s.isAtEnd && ((c=[body characterAtIndex:s.scanLocation])=='\'' || c=='"')) {
                NSString *quote=[NSString stringWithFormat:@"%C",c]; s.scanLocation++;
                [s scanUpToString:quote intoString:&value]; [s scanString:quote intoString:NULL];
            } else [s scanUpToCharactersFromSet:ws intoString:&value];
            attrs[key.lowercaseString] = RDDecode(value ?: @"");
        } else [positional addObject:RDDecode(key)];
    }
    attrs[@"positional"] = positional;
    return attrs;
}

@implementation RDMarkupParser
@synthesize delegate = _delegate;
- (id)init { if ((self=[super init])) { _pending=[NSMutableAttributedString new]; _style=[NSMutableDictionary new]; _stack=[NSMutableArray new]; _greeting=[NSMutableString new]; } return self; }
- (void)dealloc { [_pending release]; [_style release]; [_stack release]; [_greeting release]; [super dealloc]; }
- (void)reset { [_pending setAttributedString:[[[NSAttributedString alloc] initWithString:@""] autorelease]]; [_style removeAllObjects]; [_stack removeAllObjects]; [_greeting setString:@""]; _puebloActive=_html=_mxpActive=_replied=_temporarySecure=NO; _mode=_defaultMode=0; _hidden=_pre=0; }
- (void)configurePueblo:(BOOL)pueblo mxp:(BOOL)mxp { if (pueblo!=_puebloEnabled || mxp!=_mxpEnabled) [self reset]; _puebloEnabled=pueblo; _mxpEnabled=mxp; }
- (void)activateMXP:(BOOL)enabled { _mxpActive=enabled && _mxpEnabled; _mode=_defaultMode=0; [_style removeAllObjects]; [_stack removeAllObjects]; _hidden=_pre=0; }
+ (NSURL *)safeURL:(NSString *)value { if (!value || value.length>2048 || [value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound) return nil; NSURL *url=[NSURL URLWithString:value]; if (!url.host.length || url.user.length || url.password.length) return nil; return ([@[@"http",@"https"] containsObject:url.scheme.lowercaseString]) ? url : nil; }
- (void)emit:(NSAttributedString *)text to:(NSMutableAttributedString *)out {
    if (_hidden || !text.length) return;
    NSMutableAttributedString *styled=[[text mutableCopy] autorelease];
    NSMutableDictionary *overlay=[[_style mutableCopy] autorelease];
    [overlay removeObjectForKey:@"bold"]; [overlay removeObjectForKey:@"italic"];
    [styled addAttributes:overlay range:NSMakeRange(0,styled.length)];
    if ([_style[@"bold"] boolValue] || [_style[@"italic"] boolValue]) {
        [styled enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0,styled.length) options:0 usingBlock:^(id font,NSRange range,BOOL *stop) {
            NSFontTraitMask traits=([_style[@"bold"] boolValue]?NSBoldFontMask:0) | ([_style[@"italic"] boolValue]?NSItalicFontMask:0);
            NSFont *converted=[[NSFontManager sharedFontManager] convertFont:font ?: [NSFont userFixedPitchFontOfSize:12] toHaveTrait:traits];
            if (converted) [styled addAttribute:NSFontAttributeName value:converted range:range];
        }];
    }
    [out appendAttributedString:styled];
}
- (void)closeOpenTags {
    // Secure tags persist. Open tags are always at the top until mode transition.
    while (_stack.count && ![_stack.lastObject[@"secure"] boolValue]) {
        NSDictionary *frame=_stack.lastObject; [_style setDictionary:frame[@"style"]]; _hidden=[frame[@"hidden"] unsignedIntegerValue]; _pre=[frame[@"pre"] unsignedIntegerValue]; [_stack removeLastObject];
    }
}
- (BOOL)tag:(NSDictionary *)a base:(NSDictionary *)base output:(NSMutableAttributedString *)out {
    NSString *tag=a[@"tag"]; BOOL closing=[a[@"closing"] boolValue];
    BOOL mxp=_mxpActive && !_puebloActive;
    BOOL secure=!mxp || _mode==1 || _temporarySecure;
    _temporarySecure=NO;
    if (!mxp && [tag isEqualToString:@"img"] && a[@"xch_mode"] && _puebloEnabled) {
        NSString *mode=[a[@"xch_mode"] lowercaseString]; _puebloActive=YES;
        _html=[@[@"html",@"purehtml"] containsObject:mode]; return YES;
    }
    if (!mxp && _puebloActive && [tag isEqualToString:@"xch_mudtext"]) { _html=closing; return YES; }
    if ((!mxp && !(_puebloActive && _html)) || (mxp && _mode==2)) return NO;
    BOOL dangerous=[@[@"script",@"style",@"iframe",@"object",@"embed",@"form",@"head",@"title"] containsObject:tag];
    BOOL format=[@[@"b",@"strong",@"i",@"em",@"u",@"s",@"strike",@"del",@"font",@"color",@"c",@"pre"] containsObject:tag];
    BOOL block=[@[@"p",@"div"] containsObject:tag];
    BOOL link=[@[@"a",@"send"] containsObject:tag];
    if (mxp && !secure && !format) return NO;
    if (closing) {
        for (NSInteger i=(NSInteger)_stack.count-1;i>=0;i--) if ([_stack[i][@"tag"] isEqualToString:tag]) {
            NSDictionary *frame=_stack[i]; [_style setDictionary:frame[@"style"]]; _hidden=[frame[@"hidden"] unsignedIntegerValue]; _pre=[frame[@"pre"] unsignedIntegerValue]; [_stack removeObjectsInRange:NSMakeRange(i,_stack.count-i)]; break;
        }
        if (block || [tag isEqualToString:@"pre"]) [self emit:[[[NSAttributedString alloc] initWithString:@"\n" attributes:base] autorelease] to:out];
        return YES;
    }
    if (dangerous || format || block || link) {
        if (_stack.count>=64) return NO;
        [_stack addObject:@{ @"tag":tag, @"style":[NSDictionary dictionaryWithDictionary:_style], @"hidden":@(_hidden), @"pre":@(_pre), @"secure":@(secure) }];
    }
    if (dangerous) { _hidden++; return YES; }
    if (_hidden) return YES;
    NSArray *pos=a[@"positional"]; NSString *first=pos.count?pos[0]:nil;
    if ([@[@"b",@"strong"] containsObject:tag]) _style[@"bold"]=@YES;
    else if ([@[@"i",@"em"] containsObject:tag]) _style[@"italic"]=@YES;
    else if ([tag isEqualToString:@"u"]) _style[NSUnderlineStyleAttributeName]=@(NSUnderlineStyleSingle);
    else if ([@[@"s",@"strike",@"del"] containsObject:tag]) _style[NSStrikethroughStyleAttributeName]=@(NSUnderlineStyleSingle);
    else if ([@[@"font",@"color",@"c"] containsObject:tag]) {
        NSColor *color=RDColor(a[@"color"] ?: a[@"fore"] ?: a[@"fgcolor"] ?: first);
        NSColor *bg=RDColor(a[@"back"] ?: a[@"bgcolor"]);
        if (color) _style[NSForegroundColorAttributeName]=color;
        if (bg) _style[NSBackgroundColorAttributeName]=bg;
    } else if (link) {
        [_style removeObjectForKey:NSLinkAttributeName]; [_style removeObjectForKey:NSToolTipAttributeName]; [_style removeObjectForKey:NSCursorAttributeName];
        NSString *command=[tag isEqualToString:@"send"] ? (a[@"href"] ?: first) : a[@"xch_cmd"];
        BOOL prompt=a[@"prompt"]!=nil;
        for (NSString *arg in pos) if ([arg.lowercaseString isEqualToString:@"prompt"]) prompt=YES;
        if (mxp && (prompt || [command containsString:@"|"] || [command containsString:@"&text;"])) command=nil;
        NSURL *url=command ? [_delegate markupCommand:command] : ([tag isEqualToString:@"send"] ? nil : [RDMarkupParser safeURL:a[@"href"] ?: first]);
        if (url) { _style[NSLinkAttributeName]=url; _style[NSCursorAttributeName]=[NSCursor pointingHandCursor]; _style[NSToolTipAttributeName]=a[@"xch_hint"] ?: a[@"hint"] ?: a[@"title"] ?: (command ? @"Click to send this game command" : url.absoluteString); }
    } else if ([tag isEqualToString:@"img"] || [tag isEqualToString:@"image"]) {
        NSString *src=a[@"src"] ?: a[@"fname"] ?: first;
        if (mxp && a[@"url"] && src) src=[[NSURL URLWithString:src relativeToURL:[RDMarkupParser safeURL:a[@"url"]]] absoluteString];
        NSAttributedString *image=[_delegate markupImage:[RDMarkupParser safeURL:src] alternate:a[@"alt"] ?: @"Image"];
        if (image) [self emit:image to:out];
    } else if ([@[@"br",@"hr"] containsObject:tag]) [self emit:[[[NSAttributedString alloc] initWithString:[tag isEqualToString:@"hr"]?@"\n────────────────\n":@"\n" attributes:base] autorelease] to:out];
    else if ([tag isEqualToString:@"pre"]) _pre++;
    else if (block) [self emit:[[[NSAttributedString alloc] initWithString:@"\n" attributes:base] autorelease] to:out];
    else if (mxp && [tag isEqualToString:@"version"]) [_delegate markupReply:@"\033[1z<VERSION MXP=1.0 CLIENT=Atlantis VERSION=0.9.9-Pueblo-MXP>\n"];
    else if (mxp && [tag isEqualToString:@"support"]) {
        NSArray *supported=@[@"b",@"i",@"u",@"s",@"font",@"font.color",@"font.back",@"color",@"color.fore",@"color.back",@"br",@"p",@"a",@"a.href",@"send",@"send.href",@"send.hint",@"image",@"image.fname",@"image.url",@"version",@"support"];
        NSMutableArray *answers=[NSMutableArray array];
        NSArray *queries=pos.count ? pos : @[@"b",@"i",@"u",@"s",@"font",@"color",@"br",@"p",@"a",@"send",@"image",@"version",@"support"];
        NSCharacterSet *invalid=[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.*"] invertedSet];
        for (NSString *q in queries) {
            if (answers.count>=64 || !q.length || q.length>64 || [q rangeOfCharacterFromSet:invalid].location!=NSNotFound) continue;
            if ([q hasSuffix:@".*"]) {
                NSString *prefix=[q.lowercaseString substringToIndex:q.length-1]; BOOL any=NO;
                for (NSString *item in supported) if ([item hasPrefix:prefix]) { [answers addObject:[@"+" stringByAppendingString:item]]; any=YES; }
                if (!any) [answers addObject:[@"-" stringByAppendingString:q]];
            } else [answers addObject:[NSString stringWithFormat:@"%@%@",[supported containsObject:q.lowercaseString]?@"+":@"-",q]];
        }
        [_delegate markupReply:[NSString stringWithFormat:@"\033[1z<SUPPORTS %@>\n",[answers componentsJoinedByString:@" "]]];
    }
    // Unknown tags have no side effects. Declarations and scripts are unsupported.
    return YES;
}
- (NSAttributedString *)consume:(NSAttributedString *)input {
    if (!_puebloEnabled && !_mxpEnabled) return input;
    if (_puebloEnabled && !_replied) {
        [_greeting appendString:input.string]; if (_greeting.length>512) [_greeting deleteCharactersInRange:NSMakeRange(0,_greeting.length-512)];
        NSRegularExpression *re=[NSRegularExpression regularExpressionWithPattern:@"This world is Pueblo [0-9]+\\.[0-9]+ Enhanced\\." options:NSRegularExpressionCaseInsensitive error:NULL];
        if ([re firstMatchInString:_greeting options:0 range:NSMakeRange(0,_greeting.length)]) { _replied=YES; [_delegate markupReply:@"PUEBLOCLIENT 1.10\n"]; }
    }
    NSMutableAttributedString *source=[[_pending mutableCopy] autorelease]; [source appendAttributedString:input]; [_pending deleteCharactersInRange:NSMakeRange(0,_pending.length)];
    NSMutableAttributedString *out=[[[NSMutableAttributedString alloc] initWithString:@""] autorelease]; NSString *s=source.string;
    NSUInteger i=0;
    while (i<s.length) {
        unichar c=[s characterAtIndex:i]; NSDictionary *base=[source attributesAtIndex:i effectiveRange:NULL];
        if (_temporarySecure && c!='<') _temporarySecure=NO;
        if (c==27 && _mxpEnabled && !_puebloActive && i+1<s.length && [s characterAtIndex:i+1]=='[') {
            NSUInteger j=i+2; while (j<s.length && [s characterAtIndex:j]>='0' && [s characterAtIndex:j]<='9') j++;
            if (j<s.length && [s characterAtIndex:j]=='z') {
                if (!_mxpActive) { i=j+1; continue; }
                NSInteger mode=[[s substringWithRange:NSMakeRange(i+2,j-i-2)] integerValue];
                [self closeOpenTags];
                if (mode==3) { [_stack removeAllObjects]; [_style removeAllObjects]; _hidden=_pre=0; _mode=_defaultMode=0; }
                else if (mode==4) _temporarySecure=YES;
                else if (mode>=5 && mode<=7) _mode=_defaultMode=mode-5;
                else if (mode>=0 && mode<=2) _mode=mode;
                i=j+1; continue;
            }
        }
        BOOL parse=_puebloEnabled || (_mxpActive && _mode!=2);
        if (c=='<' && parse) {
            NSUInteger j=i+1; unichar quote=0;
            for (;j<s.length && j-i<=4096;j++) { unichar t=[s characterAtIndex:j]; if (quote) { if (t==quote) quote=0; } else if (t=='\'' || t=='"') quote=t; else if (t=='>') break; }
            if (j==s.length && j-i<=4096) { [_pending appendAttributedString:[source attributedSubstringFromRange:NSMakeRange(i,s.length-i)]]; break; }
            if (j<s.length && [s characterAtIndex:j]=='>') {
                NSRange range=NSMakeRange(i,j-i+1);
                if ([self tag:RDTag([s substringWithRange:range]) base:base output:out]) { i=j+1; continue; }
                [self emit:[source attributedSubstringFromRange:range] to:out]; i=j+1; continue;
            }
        }
        BOOL markup=(_puebloActive && _html) || (_mxpActive && !_puebloActive && _mode!=2);
        if (c=='&' && markup) {
            NSRange semi=[s rangeOfString:@";" options:0 range:NSMakeRange(i,MIN(40,s.length-i))];
            if (semi.location!=NSNotFound) {
                NSString *decoded=RDEntity([s substringWithRange:NSMakeRange(i+1,semi.location-i-1)]);
                if (decoded) { [self emit:[[[NSAttributedString alloc] initWithString:decoded attributes:base] autorelease] to:out]; i=NSMaxRange(semi); continue; }
            } else if (s.length-i<40 && [s rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet options:0 range:NSMakeRange(i,s.length-i)].location==NSNotFound) { [_pending appendAttributedString:[source attributedSubstringFromRange:NSMakeRange(i,s.length-i)]]; break; }
        }
        // Emit contiguous runs rather than one attributed string per character.
        NSUInteger end=i+1;
        if (c!='\n') while (end<s.length) { unichar next=[s characterAtIndex:end]; if (next=='<' || next=='&' || next==27 || next=='\n') break; end++; }
        [self emit:[source attributedSubstringFromRange:NSMakeRange(i,end-i)] to:out];
        if (c=='\n' && _mxpActive && !_puebloActive) { [self closeOpenTags]; _mode=_defaultMode; _temporarySecure=NO; }
        i=end;
    }
    return out;
}
@end
