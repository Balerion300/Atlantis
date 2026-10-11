//
//  RDAnsiFilter.m
//  Atlantis
//
//  Created by Rachel Blackman on 2/11/06.
//  Copyright 2006 Riverdark Studios. All rights reserved.
//

#import "RDAnsiFilter.h"
#import "RDAtlantisMainController.h"
#import "NSColorAdditions.h"

static NSMutableArray *s_extendedColors = nil;

@implementation RDAnsiState

+ (void) initialize
{
	if (!s_extendedColors) {
		s_extendedColors = [[NSMutableArray alloc] init];
        int loop1, loop2, loop3;

		NSArray *points = [NSArray arrayWithObjects:@"00",@"5f",@"87",@"af",@"d7",@"ff",nil];
		for (loop1 = 0; loop1 < [points count]; loop1++) {
			for (loop2 = 0; loop2 < [points count]; loop2++) {
				for (loop3 = 0; loop3 < [points count]; loop3++) {
					NSString *colorString = [NSString stringWithFormat:@"%@%@%@",
											 [points objectAtIndex:loop1],
											 [points objectAtIndex:loop2],
											 [points objectAtIndex:loop3]];
					
					[s_extendedColors addObject:[NSColor colorWithWebCode:colorString]];
				}
			}
		}
		
        int colorLoop;
        
		for (colorLoop = 0; colorLoop < 24; colorLoop++) {
			NSString *colorString = [NSString stringWithFormat:@"%02X%02X%02X",
									 (colorLoop * 10) + 8, (colorLoop * 10) + 8, (colorLoop * 10) + 8];
			
			[s_extendedColors addObject:[NSColor colorWithWebCode:colorString]];
		}
	}
}

- (id) init
{
    _rdAnsiBoldMe = NO;
    _rdAnsiInvertMe = NO;
    _rdAnsiUnderlineMe = NO;
    
    _rdAnsiLastColor = 7;
    _rdAnsiLastBackground = -1;
    
    _rdHoldover = nil;
    _rdFont = [[NSFont userFixedPitchFontOfSize:10.0f] retain];
    _rdFontBold = [[[NSFontManager sharedFontManager] convertFont:_rdFont toHaveTrait:NSBoldFontMask] retain];
    _rdBoldOnIntense = NO;
    
    _rdBackground = [[NSColor blackColor] retain];
    _rdDefaultColor = [[NSColor colorWithCalibratedRed:0.8f green:0.8f blue:0.8f alpha:1.0f] retain];
    
    _rdCurrentAttributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:_rdFont,NSFontAttributeName,_rdBackground,NSBackgroundColorAttributeName,_rdDefaultColor,NSForegroundColorAttributeName,nil];    
    
    return self;
}

- (void) dealloc
{
    [_rdCurrentAttributes release];
    [_rdParaStyle release];
    [_rdFontBold release];
    [_rdFont release];
    [_rdColors release];
    [_rdBackground release];
    [super dealloc];
}

- (BOOL) bold
{
    return _rdAnsiBoldMe;
}

- (BOOL) invert
{
    return _rdAnsiInvertMe;
}

- (BOOL) underline
{
    return _rdAnsiUnderlineMe;
}

- (int) lastColor
{
    return _rdAnsiLastColor;
}

- (int) lastBackground
{
    return _rdAnsiLastBackground;
}

- (NSAttributedString *) holdover
{
    return _rdHoldover;
}

- (void) setBold:(BOOL)bold
{
    _rdAnsiBoldMe = bold;
    
    if ((_rdAnsiLastColor != -1) && (_rdAnsiLastColor > [_rdColors count]))
        return;
    
    int effFg = _rdAnsiLastColor + (((_rdAnsiLastColor != -1) && (_rdAnsiLastColor < 8)) ? (_rdAnsiBoldMe ? 8 : 0) : 0);
    NSColor *fgColor = nil;

    if (_rdAnsiLastColor == -1) {
        if (_rdAnsiBoldMe) {
            fgColor = [_rdColors objectAtIndex:15];
            effFg = 15;
        }
        else {
            fgColor = _rdDefaultColor;
        }
    }
     else if (effFg < [_rdColors count])
        fgColor = [_rdColors objectAtIndex:effFg];

    if (fgColor)
        [_rdCurrentAttributes setObject:fgColor forKey:(_rdAnsiInvertMe ? NSBackgroundColorAttributeName : NSForegroundColorAttributeName)];

    if ((effFg != -1) && (effFg < [_rdColors count]))
        [_rdCurrentAttributes setObject:[NSNumber numberWithInt:effFg] forKey:(_rdAnsiInvertMe ? @"RDAnsiBackgroundColor" : @"RDAnsiForegroundColor")];
    else
        [_rdCurrentAttributes removeObjectForKey:(_rdAnsiInvertMe ? @"RDAnsiBackgroundColor" : @"RDAnsiForegroundColor")];
        
    if (_rdBoldOnIntense)
        [_rdCurrentAttributes setObject:(_rdAnsiBoldMe ? _rdFontBold : _rdFont) forKey:NSFontAttributeName];
}

- (void) setInvert:(BOOL)invert
{
    _rdAnsiInvertMe = invert;

    NSColor *fgColor;
    NSColor *bgColor;
    
    int effFg = _rdAnsiLastColor + (((_rdAnsiLastColor != -1) && (_rdAnsiLastColor < 8)) ? (_rdAnsiBoldMe ? 8 : 0) : 0);
    int effBg = _rdAnsiLastBackground;

    if (_rdAnsiLastColor == -1) {
        if (_rdAnsiBoldMe) {
            fgColor = [_rdColors objectAtIndex:15];
            effFg = 15;
        }
        else {
            fgColor = _rdDefaultColor;
        }
    }
    else if (effFg < [_rdColors count]) {
        fgColor = [_rdColors objectAtIndex:effFg];
    }
    else {
        int tempFg = effFg - 16;
        
        fgColor = [s_extendedColors objectAtIndex:tempFg];
    }

    if (_rdAnsiLastBackground == -1)
        bgColor = _rdBackground;
    else if (effBg < [_rdColors count]) {
        bgColor = [_rdColors objectAtIndex:effBg];
    }
    else {
        int tempBg = effBg - 16;
        
        bgColor = [s_extendedColors objectAtIndex:tempBg];
    }

    if ((effFg != -1) && (effFg < [_rdColors count]))
        [_rdCurrentAttributes setObject:[NSNumber numberWithInt:effFg] forKey:(_rdAnsiInvertMe ? @"RDAnsiBackgroundColor" : @"RDAnsiForegroundColor")];
    else
        [_rdCurrentAttributes removeObjectForKey:(_rdAnsiInvertMe ? @"RDAnsiBackgroundColor" : @"RDAnsiForegroundColor")];
        [_rdCurrentAttributes removeObjectForKey:(_rdAnsiInvertMe ? NSForegroundColorAttributeName : NSBackgroundColorAttributeName)];

    if ((effBg != -1) && (effBg < [_rdColors count]))
        [_rdCurrentAttributes setObject:[NSNumber numberWithInt:effBg] forKey:(_rdAnsiInvertMe ? @"RDAnsiForegroundColor" : @"RDAnsiBackgroundColor")];
    else
        [_rdCurrentAttributes removeObjectForKey:(_rdAnsiInvertMe ? @"RDAnsiForegroundColor" : @"RDAnsiBackgroundColor")];
        [_rdCurrentAttributes removeObjectForKey:(_rdAnsiInvertMe ? NSForegroundColorAttributeName : NSBackgroundColorAttributeName)];

    if (fgColor)
        [_rdCurrentAttributes setObject:fgColor forKey:(_rdAnsiInvertMe ? NSBackgroundColorAttributeName : NSForegroundColorAttributeName)];
    if (bgColor)
        [_rdCurrentAttributes setObject:bgColor forKey:(_rdAnsiInvertMe ? NSForegroundColorAttributeName : NSBackgroundColorAttributeName)];
}

- (void) setUnderline:(BOOL)underline
{
    _rdAnsiUnderlineMe = underline;

    int underlineStyle = NSUnderlineStyleNone;
    
    if (_rdAnsiUnderlineMe) {
        underlineStyle = NSUnderlineStyleSingle;
    }
    
    [_rdCurrentAttributes setObject:[NSNumber numberWithInt:underlineStyle] forKey:NSUnderlineStyleAttributeName];
}

- (void) setStrikeThrough:(BOOL)strikethrough
{
    _rdAnsiStrikeThroughMe = strikethrough;

    int strikeThroughStyle = NSUnderlineStyleNone;
    float strikeThroughBaselineOffset = 0;
    
    if (_rdAnsiStrikeThroughMe) {
        strikeThroughStyle = [NSNumber numberWithInteger:NSUnderlineStyleSingle | NSUnderlineStylePatternDot];
        strikeThroughBaselineOffset = 0.1;
    }
    
    [_rdCurrentAttributes setObject:[NSNumber numberWithInt:strikeThroughStyle] forKey:NSStrikethroughStyleAttributeName];
    [_rdCurrentAttributes setObject:[NSNumber numberWithFloat:strikeThroughBaselineOffset] forKey:NSBaselineOffsetAttributeName];
}

- (void) setColor:(int)color
{
    _rdAnsiLastColor = color;
    
    int effFg = _rdAnsiLastColor + (((_rdAnsiLastColor != -1) && (_rdAnsiLastColor < 8)) ? (_rdAnsiBoldMe ? 8 : 0) : 0);
    NSColor *fgColor = nil;

    if (_rdAnsiLastColor == -1) {
        if (_rdAnsiBoldMe) {
            fgColor = [_rdColors objectAtIndex:15];
            effFg = 15;
        }
        else {
            fgColor = _rdDefaultColor;
        }
    }
	else if (effFg < [_rdColors count]) {
        fgColor = [_rdColors objectAtIndex:effFg];
	}
	else {
		int tempFg = effFg - 16;
		
		if (tempFg < [s_extendedColors count])
			fgColor = [s_extendedColors objectAtIndex:tempFg];
	}

    if ((effFg != -1) && (effFg < 16))
        [_rdCurrentAttributes setObject:[NSNumber numberWithInt:effFg] forKey:(_rdAnsiInvertMe ? @"RDAnsiBackgroundColor" : @"RDAnsiForegroundColor")];
    else
        [_rdCurrentAttributes removeObjectForKey:(_rdAnsiInvertMe ? @"RDAnsiBackgroundColor" : @"RDAnsiForegroundColor")];

    if (fgColor)
        [_rdCurrentAttributes setObject:fgColor forKey:(_rdAnsiInvertMe ? NSBackgroundColorAttributeName : NSForegroundColorAttributeName)];
}

- (void) setBackground:(int)background
{
    _rdAnsiLastBackground = background;

    NSColor *bgColor = nil;

    if (_rdAnsiLastBackground == -1)
        bgColor = _rdBackground;
    else if (_rdAnsiLastBackground < [_rdColors count])
        bgColor = [_rdColors objectAtIndex:_rdAnsiLastBackground];
	else {
		int tempBg = _rdAnsiLastBackground - 16;
		
		if (tempBg < [s_extendedColors count])
			bgColor = [s_extendedColors objectAtIndex:tempBg];
	}
	
    if ((_rdAnsiLastBackground != -1) && (_rdAnsiLastBackground < 16))
        [_rdCurrentAttributes setObject:[NSNumber numberWithInt:_rdAnsiLastBackground] forKey:(_rdAnsiInvertMe ? @"RDAnsiForegroundColor" : @"RDAnsiBackgroundColor")];
    else 
        [_rdCurrentAttributes removeObjectForKey:(_rdAnsiInvertMe ? @"RDAnsiForegroundColor" : @"RDAnsiBackgroundColor")];

    if (bgColor)
        [_rdCurrentAttributes setObject:bgColor forKey:(_rdAnsiInvertMe ? NSForegroundColorAttributeName : NSBackgroundColorAttributeName)];
	else 
        [_rdCurrentAttributes removeObjectForKey:(_rdAnsiInvertMe ? NSForegroundColorAttributeName : NSBackgroundColorAttributeName)];
}

- (void) setHoldover:(NSAttributedString *)string
{
    if (_rdHoldover) {
        [_rdHoldover release];
        _rdHoldover = nil;
    }
    
    if (string) {
        _rdHoldover = string;
        [_rdHoldover retain];
    }
}

- (void) reset
{
    _rdAnsiLastBackground = -1;
    _rdAnsiLastColor = -1;
    _rdAnsiBoldMe = NO;
    _rdAnsiInvertMe = NO;
    _rdAnsiUnderlineMe = NO;

    [_rdCurrentAttributes release];
    _rdCurrentAttributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSDate date],@"RDTimeStamp",_rdFont,NSFontAttributeName,_rdBackground,NSBackgroundColorAttributeName,_rdDefaultColor,NSForegroundColorAttributeName,_rdParaStyle,NSParagraphStyleAttributeName,nil];        
}

- (void) setColorArray:(NSArray *) colors
{
    if (colors) {
        if (_rdColors) {
            [_rdColors release];
            _rdColors = nil;
        }
        
        _rdColors = [colors retain];
    }
}

- (void) setDocumentBackground:(NSColor *) background
{
    if (background) {
        [_rdBackground release];
        _rdBackground = [background retain];
    }
}

- (void) setDocumentDefault:(NSColor *) defaultColor
{
    if (defaultColor) {
        [_rdDefaultColor release];
        _rdDefaultColor = [defaultColor retain];
    }
}

- (void) setParagraphStyle:(NSParagraphStyle *)paraStyle
{
    [_rdCurrentAttributes setObject:paraStyle forKey:NSParagraphStyleAttributeName];
    [_rdParaStyle release];
    _rdParaStyle = [paraStyle retain];
}

- (void) setFont:(NSFont *) font
{
    if (font && (!_rdFont || ![font isEqualTo:_rdFont])) {
        [_rdFont release];
        _rdFont = [font retain];
        
        [_rdFontBold release];
        _rdFontBold = [[[NSFontManager sharedFontManager] convertFont:_rdFont toHaveTrait:NSBoldFontMask] retain];        
    }
}

- (void) setBoldOnIntense:(BOOL) bOnIntense
{
    _rdBoldOnIntense = bOnIntense;
}

- (void) setTimestamp:(NSDate *)timestamp
{
    [_rdCurrentAttributes setObject:timestamp forKey:@"RDTimeStamp"];
}

- (NSDictionary *) attributes
{
    return _rdCurrentAttributes;
}

@end


@implementation RDAnsiFilter

- (id) initWithWorld:(RDAtlantisWorldInstance *)world
{
    self = [super initWithWorld:world];
    if (self) {
        _rdState = [[RDAnsiState alloc] init];
        [_rdState setColorArray:[world preferenceForKey:@"atlantis.colors.ansi"]];
        [_rdState setParagraphStyle:[world paragraphStyle]];
        NSColor *tempColor = [world preferenceForKey:@"atlantis.colors.background"];
        if (tempColor)        
            [_rdState setDocumentBackground:tempColor];

        tempColor = [world preferenceForKey:@"atlantis.colors.default"];
        if (tempColor)        
            [_rdState setDocumentDefault:tempColor];
            
        NSFont *font = [world preferenceForKey:@"atlantis.formatting.font"];
        if (font) 
            [_rdState setFont:font];
        NSNumber *boldTest = [[self world] preferenceForKey:@"atlantis.formatting.boldIntense"];
        if (boldTest) {
            [_rdState setBoldOnIntense:[boldTest boolValue]];
        }
        else {
            boldTest = [[[RDAtlantisMainController controller] globalWorld] preferenceForKey:@"atlantis.formatting.boldIntense" withCharacter:nil];
            if (boldTest)
                [_rdState setBoldOnIntense:[boldTest boolValue]];
            else
                [_rdState setBoldOnIntense:NO];
        }
            
        [_rdState reset];
    }
    return self;
}

- (void) dealloc
{
    [_rdState release];
    [super dealloc];
}

- (void) worldWasRefreshed
{
    [_rdState setColorArray:[[self world] preferenceForKey:@"atlantis.colors.ansi"]];
    [_rdState setParagraphStyle:[[self world] paragraphStyle]];
    NSColor *tempColor = [[self world] preferenceForKey:@"atlantis.colors.background"];
    if (tempColor)        
        [_rdState setDocumentBackground:tempColor];
    tempColor = [[self world] preferenceForKey:@"atlantis.colors.default"];
    if (tempColor)        
        [_rdState setDocumentDefault:tempColor];
    NSFont *font = [[self world] preferenceForKey:@"atlantis.formatting.font"];
    if (font)
        [_rdState setFont:font];
    NSNumber *boldTest = [[self world] preferenceForKey:@"atlantis.formatting.boldIntense"];
    if (boldTest) {
        [_rdState setBoldOnIntense:[boldTest boolValue]];
    }
    else {
        boldTest = [[[RDAtlantisMainController controller] globalWorld] preferenceForKey:@"atlantis.formatting.boldIntense" withCharacter:nil];
        if (boldTest)
            [_rdState setBoldOnIntense:[boldTest boolValue]];
        else
            [_rdState setBoldOnIntense:NO];
    }
    NSNumber *beepTest = [[self world] preferenceForKey:@"atlantis.formatting.beep"];
    if (beepTest) {
        _rdBeepBehavior = [beepTest intValue];
    }
    else {
        _rdBeepBehavior = 0;
    }
}

- (void) filterInput:(id) input
{
    if ([input isKindOfClass:[NSMutableAttributedString class]]) {
        NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:@"" attributes:[_rdState attributes]];
        NSMutableAttributedString *string = [(NSMutableAttributedString *)input mutableCopy];
        
        // Grab any leftover unterminated ANSI codes?
        if ([_rdState holdover]) {
            [string insertAttributedString:[_rdState holdover] atIndex:0];
            [_rdState setHoldover:nil];
        }
        [_rdState setTimestamp:[NSDate date]];
        
        NSUInteger lastPosition = 0;
        NSString *tempString = [string string];
        NSUInteger length = [tempString length];
        
        // Handle bell
        NSRange foundRange = [tempString rangeOfString:@"\x07" options:0 range:NSMakeRange(0,[tempString length])];
        if (foundRange.length) {
            switch ([[NSUserDefaults standardUserDefaults] integerForKey:@"atlantis.beeptype"]) {
                case 0: // Do nothing
                    break;
                case 1: // Show status
                    [[self world] outputStatus:@"Beep!" toSpawn:@""];
                    break;
                case 2: // System beep
                    NSBeep();
                    break;
            }
        }
        
        bool done = false;
        while (!done) {
            
            if (lastPosition >= length) {
                done = true;
                continue;
            }
            
            // Find where the next escape sequence starts
            NSRange testRange = NSMakeRange(lastPosition, length - lastPosition);
            foundRange = [tempString rangeOfString:@"\x1b" options:0 range:testRange];
            
            // If there are no escape sequences, then emit the whole thing with the current attributes
            if (!foundRange.length) {
                NSRange realRange = NSMakeRange(lastPosition, length - lastPosition);
                NSString *test = [[string string] substringWithRange:realRange];
                [result appendAttributedString:[[[NSAttributedString alloc] initWithString:test attributes:[_rdState attributes]] autorelease]];
                
                // DEBUG
                // NSLog(@"NONE >%@< %lu %hu %hu", test, [test length], [test characterAtIndex:0], [test characterAtIndex:[test length] - 1]);
                
                done = true;
                continue;
            }
            
            // If we get here, there's an escape sequence ahead...
            
            // If there is plain text before the escape sequence, emit that with with current attributes
            if (foundRange.length && (foundRange.location > lastPosition)) {
                NSRange realRange = NSMakeRange(lastPosition, foundRange.location - lastPosition);
                NSString *test = [[string string] substringWithRange:realRange];
                [result appendAttributedString:[[[NSAttributedString alloc] initWithString:test attributes:[_rdState attributes]] autorelease]];
                
                // DEBUG
                //NSLog(@"TEXT >%@< %lu %hu %hu", test, [test length], [test characterAtIndex:0], [test characterAtIndex:[test length] - 1]);
                
                // Advance the last position to the escape sequence and continue
                lastPosition = foundRange.location;
                //continue;
            }
            
            // Handle escape sequence start
            if (foundRange.length && (foundRange.location == lastPosition)) {
                
                // If an escape character is at the very end of the packet, it is incomplete.
                // In this particular case, stuff it into the holdover buffer and continue.
                if (foundRange.location == (length - 1)) {
                    NSRange realRange = NSMakeRange(lastPosition, length - lastPosition);
                    NSAttributedString *test = [string attributedSubstringFromRange:realRange];
                    [_rdState setHoldover:test];
                    done = true;
                    continue;
                }
                
                // Otherwise, see what sort of escape sequence it is and if we can find the end of it
                NSUInteger searchBegin = foundRange.location + foundRange.length;
                NSRange finishRange = NSMakeRange(searchBegin, length - searchBegin);
                NSRange endRange;
                
                unichar nextChar = [[string string] characterAtIndex: lastPosition + 1];
                switch (nextChar) {
                        
                        // Two character sequences, read out two characters and parse it
                    case 32: // " " Used by xterm for 7/8-bit and charsets
                    case 35: // "#" Various DEC commands
                    case 37: // "%" Used by xterm for UTF-8 settings
                    case 64: // "@" Unknown, implemented in urxvt
                    case 71: // "G" Unsupported rxvt graphics
                        
                        // If we don't have two more bytes to read, it's incomplete.
                        // Stuff them into the holdover buffer and continue
                        if ((lastPosition + 2) > (length - 1)) {
                            NSRange realRange = NSMakeRange(lastPosition, length - lastPosition);
                            NSAttributedString *test = [string attributedSubstringFromRange:realRange];
                            [_rdState setHoldover:test];
                            done = true;
                            continue;
                        }
                        else {
                            endRange = NSMakeRange(lastPosition + 2, 1);
                        }
                        break;
                        
                        // String type sequences
                    case 80: // "P" DCS, ends with ST (ESC \)
                    case 88: // "X" SOS, ends with ST (ESC \)
                    case 93: // "]" OSC, ends with ST (ESC \)
                    case 94: // "^" PM,  ends with ST (ESC \)
                    case 95: // "_" APC, ends with ST (ESC \)
                        endRange = [tempString rangeOfString:@"\x1b\x5c" options:0 range:finishRange];
                        break;
                    case 91: // "[" CSI, sequence ends with a letter
                        endRange = [tempString rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet] options:0 range:finishRange];
                        break;
                        
                        // Single-character sequences, read out the next character and parse it
                    default:
                        endRange = NSMakeRange(lastPosition + 1, 1);
                        break;
                }
                
                // We have a complete string type escape sequence, so we collect it and parse it
                if (endRange.length) {
                    NSRange realRange = NSMakeRange(lastPosition, endRange.location + endRange.length - lastPosition);
                    NSString *test = [[string string] substringWithRange:realRange];
                    
                    // DEBUG
                    //NSLog(@"ANSI >%@< %lu %hu", test, [test length], [test characterAtIndex:[test length] - 1]);
                    
                    [self parseEscapeSequence:test result:result];
                    
                    // Advance the last position past the escape sequence
                    lastPosition = endRange.location + endRange.length;
                    continue;
                }
                else {
                    // We have an incomplete escape sequence, so put the remainder into the holdover buffer
                    NSRange realRange = NSMakeRange(lastPosition, length - lastPosition);
                    NSAttributedString *test = [string attributedSubstringFromRange:realRange];
                    [_rdState setHoldover:test];
                    
                    //NSLog(@"HOLD >%@< %lu", [test string], [test length]);
                    done = true;
                    continue;
                }
                
            }
        }
        
        [string release];
        [(NSMutableAttributedString *)input setAttributedString:result];
        [result release];
    }
}

- (void) parseEscapeSequence:(NSString *)sequence result:(NSMutableAttributedString *) result
{
    NSString *escTerminator = [sequence substringFromIndex:[sequence length] - 1];

    // The display parser needs MXP line modes at their original text positions.
    if ([escTerminator isEqualToString:@"z"] && [[[self world] preferenceForKey:@"atlantis.mxp.enabled"] boolValue]) {
        [result appendAttributedString:[[[NSAttributedString alloc] initWithString:sequence attributes:[_rdState attributes]] autorelease]];
        return;
    }
    
    // ANSI color sequence
    if ([escTerminator isEqualToString:@"m"]) {
        NSString *ansiSequence = [sequence substringWithRange:NSMakeRange(2, [sequence length] - 2)];
        
        NSArray *ansicodes = [ansiSequence componentsSeparatedByString:@";"];
        NSEnumerator *ansiEnum = [ansicodes objectEnumerator];
        
        id walkobj;
        while (walkobj = [ansiEnum nextObject]) {
            int code = [(NSString *)walkobj intValue];
            
            // Get ANSI sequence category
            switch (code / 10) {
                
                case 0: // ANSI attribute set
                case 2: // ANSI attribute clear
                {
                    BOOL toggle = ((code / 10) == 0);
                    
                    switch (code % 10) {
                        case 0: // ANSI reset
                            [_rdState reset];
                            break;
                            
                        case 1: // ANSI bold on / off
                            [_rdState setBold:toggle];
                            break;
                            
                        case 3: // ANSI italics on / off
                            break;
                            
                        case 4: // ANSI underline on /off
                            [_rdState setUnderline:toggle];
                            break;
                            
                        case 7: // ANSI inverse on / off
                            [_rdState setInvert:toggle];
                            break;
                            
                        case 9: // ANSI strike-through on / off
                            [_rdState setStrikeThrough:toggle];
                            break;
                    }
                }
                    break;
                    
                case 3: // ANSI foreground color
                    if (code < 38)
                        [_rdState setColor:(code - 30)];
                    else if (code == 39) {
                        [_rdState setColor:-1];
                        [_rdState setBold:FALSE];
                    }
                    else if (code == 38) {
                        // 256-color support
                        NSString *nextObj = [ansiEnum nextObject];
                        if ([nextObj isEqualToString:@"5"]) {
                            nextObj = [ansiEnum nextObject];
                            [_rdState setColor:[nextObj intValue]];
                        }
                    }
                    break;
                    
                case 4: // ANSI background color
                    if (code < 48)
                        [_rdState setBackground:(code - 40)];
                    else if (code == 49)
                        [_rdState setBackground:-1];
                    else if (code == 48) {
                        // 256-color support
                        NSString *nextObj = [ansiEnum nextObject];
                        if ([nextObj isEqualToString:@"5"]) {
                            nextObj = [ansiEnum nextObject];
                            [_rdState setBackground:[nextObj intValue]];
                        }
                    }
                    break;
                    
                case 9: // ANSI extended foreground
                    [_rdState setColor:((code - 90) + 8)];
                    break;
                    
                case 10:
                    [_rdState setBackground:((code - 100) + 8)];
                    break;
            }
        }
    }
    else if ([escTerminator isEqualToString:@"a"]) {
        // Atlantis private escape sequences
        NSString *ansiSequence = [sequence substringWithRange:NSMakeRange(2, [sequence length] - 2)];
        
        NSArray *ansicodes = [ansiSequence componentsSeparatedByString:@";"];
        NSEnumerator *ansiEnum = [ansicodes objectEnumerator];
        
        id walkobj;
        while (walkobj = [ansiEnum nextObject]) {
            int code = [walkobj intValue];
            switch (code) {
                case 1:
                    {
                        // MUD prompt marker
                        NSCharacterSet *linefeedSet = [NSCharacterSet characterSetWithCharactersInString:@"\n\r"];
                        NSRange lineMarker = [[result string] rangeOfCharacterFromSet:linefeedSet options:NSBackwardsSearch];
                        if (lineMarker.location == NSNotFound) {
                            lineMarker = NSMakeRange(0,[result length]);
                        }
                        else {
                            lineMarker.length = [result length] - lineMarker.location;
                        }
                        [result addAttribute:@"RDPromptMarker" value:@"yes" range:lineMarker];
                    }
                    break;
            }
        }
    }
}

@end
