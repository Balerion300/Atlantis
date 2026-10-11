#import <Cocoa/Cocoa.h>
@protocol RDMarkupImageDelegate <NSObject>
- (void) markupAttachmentChanged:(NSTextAttachment *)attachment;
@end
@interface RDMarkupImageLoader : NSObject <NSURLSessionDataDelegate> {
    NSURLSession *_session;
    NSMutableDictionary *_requests;
    id<RDMarkupImageDelegate> _delegate;
}
@property(assign) id<RDMarkupImageDelegate> delegate;
- (NSAttributedString *)image:(NSURL *)url alternate:(NSString *)alternate;
- (void)shutdown;
@end
