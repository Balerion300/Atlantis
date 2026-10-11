#import <Cocoa/Cocoa.h>

@class RDMarkupParser;
@protocol RDMarkupDelegate <NSObject>
- (void) markupReply:(NSString *)reply;
- (NSURL *) markupCommand:(NSString *)command;
- (NSAttributedString *) markupImage:(NSURL *)url alternate:(NSString *)alternate;
@end

// Streaming display subset. This deliberately does not invoke a browser or HTML importer.
@interface RDMarkupParser : NSObject {
    id<RDMarkupDelegate> _delegate; // non-owning; cleared by owner before disposal
    BOOL _puebloEnabled, _mxpEnabled, _puebloActive, _html, _mxpActive, _replied;
    NSInteger _mode, _defaultMode;
    BOOL _temporarySecure;
    NSMutableAttributedString *_pending;
    NSMutableDictionary *_style;
    NSMutableArray *_stack;
    NSMutableString *_greeting;
    NSUInteger _hidden, _pre;
    NSUInteger _puebloBreakEnding; // 1: optional wire ending, 2: optional LF after CR
    BOOL _hasOutput;
    unichar _lastCharacter;
}
@property(assign) id<RDMarkupDelegate> delegate;
- (void) configurePueblo:(BOOL)pueblo mxp:(BOOL)mxp;
- (void) reset;
- (void) activateMXP:(BOOL)enabled;
- (NSAttributedString *) consume:(NSAttributedString *)input;
+ (NSURL *) safeURL:(NSString *)value;
@end
