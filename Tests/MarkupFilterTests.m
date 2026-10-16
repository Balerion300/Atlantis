#import <Cocoa/Cocoa.h>
#import "RDMarkupFilter.h"
@implementation RDAtlantisWorldInstance
- (id)preferenceForKey:(NSString *)key { return @NO; }
- (void)sendString:(NSString *)text { [NSException raise:@"Unexpected send" format:@"Disabled filter sent output"]; }
- (NSEnumerator *)spawnEnumerator { return [@[] objectEnumerator]; }
@end
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    RDAtlantisWorldInstance *world=[RDAtlantisWorldInstance new];
    RDMarkupFilter *filter=[[RDMarkupFilter alloc] initWithWorld:world];
    for (NSString *text in @[@"Plain output\n",@"<Guest> Regular channel.\n",@"Name   Location   Idle\n"]) {
        NSMutableAttributedString *input=[[[NSMutableAttributedString alloc] initWithString:text attributes:@{NSForegroundColorAttributeName:NSColor.cyanColor}] autorelease];
        [input addAttribute:NSFontAttributeName value:[NSFont userFixedPitchFontOfSize:12] range:NSMakeRange(0,4)];
        NSAttributedString *expected=[[input copy] autorelease];
        [filter filterInput:input];
        if (![input isEqualToAttributedString:expected]) { NSLog(@"FAIL disabled filter preserves styled output: %@",text);return 1; }
    }
    NSLog(@"3 disabled-filter styled-output checks passed");
    [filter release];[world release];return 0;
} }
