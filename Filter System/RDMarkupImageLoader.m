#import "RDMarkupImageLoader.h"
#import "RDMarkupParser.h"
#import <ImageIO/ImageIO.h>

@implementation RDMarkupImageLoader
@synthesize delegate = _delegate;
- (id)init {
    if ((self=[super init])) {
        _requests=[NSMutableDictionary new];
        NSURLSessionConfiguration *config=[NSURLSessionConfiguration ephemeralSessionConfiguration];
        config.HTTPMaximumConnectionsPerHost=4; config.timeoutIntervalForRequest=10; config.timeoutIntervalForResource=20;
        config.URLCache=nil; config.HTTPCookieStorage=nil;
        _session=[[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:NSOperationQueue.mainQueue] retain];
    } return self;
}
- (void)shutdown { _delegate=nil; [_session invalidateAndCancel]; [_session release]; _session=nil; [_requests removeAllObjects]; }
- (void)dealloc { [_requests release]; [super dealloc]; }
- (NSAttributedString *)image:(NSURL *)url alternate:(NSString *)alternate {
    if (!_session || !url || _requests.count>=16) return [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"[%@]",alternate]] autorelease];
    NSTextAttachment *attachment=[[[NSTextAttachment alloc] init] autorelease];
    NSTextAttachmentCell *cell=[[[NSTextAttachmentCell alloc] initTextCell:[NSString stringWithFormat:@"[%@: loading]",alternate]] autorelease];
    [attachment setAttachmentCell:cell];
    NSURLSessionDataTask *task=[_session dataTaskWithURL:url];
    _requests[@(task.taskIdentifier)]=[NSMutableDictionary dictionaryWithDictionary:@{ @"data":[NSMutableData data], @"attachment":attachment, @"alternate":alternate, @"redirects":@0 }];
    [task resume];
#ifdef RD_MARKUP_TEST
    NSLog(@"Image task started: %lu",(unsigned long)task.taskIdentifier);
#endif
    NSMutableAttributedString *text=[[[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy] autorelease];
    [text addAttribute:NSToolTipAttributeName value:alternate range:NSMakeRange(0,text.length)]; return text;
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completion {
#ifdef RD_MARKUP_TEST
    NSLog(@"Image response received: %lu",(unsigned long)task.taskIdentifier);
#endif
    BOOL valid=_requests[@(task.taskIdentifier)]!=nil && [response isKindOfClass:NSHTTPURLResponse.class] && [(NSHTTPURLResponse *)response statusCode]==200 && response.expectedContentLength<=2*1024*1024;
    // ImageIO verifies actual format; tolerate mislabelled game-image servers.
    completion(valid?NSURLSessionResponseAllow:NSURLSessionResponseCancel);
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completion {
    NSMutableDictionary *state=_requests[@(task.taskIdentifier)];
    NSInteger redirects=[state[@"redirects"] integerValue]+1; state[@"redirects"]=@(redirects);
    completion(state && redirects<=3 && [RDMarkupParser safeURL:request.URL.absoluteString] ? request : nil);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    NSMutableData *buffer=_requests[@(task.taskIdentifier)][@"data"];
    if (!buffer || data.length>2*1024*1024-buffer.length) { [task cancel]; return; }
    [buffer appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
#ifdef RD_MARKUP_TEST
    NSLog(@"Image completed: %lu error domain=%@ code=%ld",(unsigned long)task.taskIdentifier,error.domain,(long)error.code);
#endif
    NSDictionary *state=[[_requests[@(task.taskIdentifier)] retain] autorelease];
    if (!state) return;
    NSTextAttachment *attachment=state[@"attachment"];
    NSImage *image=nil;
    if (!error && _delegate) {
        CGImageSourceRef source=CGImageSourceCreateWithData((CFDataRef)state[@"data"], (CFDictionaryRef)@{(id)kCGImageSourceShouldCache:@NO});
        if (source) {
            NSDictionary *props=(NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source,0,NULL);
            NSUInteger w=[props[(id)kCGImagePropertyPixelWidth] unsignedIntegerValue], h=[props[(id)kCGImagePropertyPixelHeight] unsignedIntegerValue];
            if (w>0 && h>0 && w<=4096 && h<=4096 && w*h<=4*1024*1024) {
                CGImageRef thumbnail=CGImageSourceCreateThumbnailAtIndex(source,0,(CFDictionaryRef)@{ (id)kCGImageSourceCreateThumbnailFromImageAlways:@YES, (id)kCGImageSourceThumbnailMaxPixelSize:@560, (id)kCGImageSourceCreateThumbnailWithTransform:@YES });
                if (thumbnail) {
                    CGFloat scale=MIN(1.0,MIN(560.0/CGImageGetWidth(thumbnail),320.0/CGImageGetHeight(thumbnail)));
                    image=[[[NSImage alloc] initWithCGImage:thumbnail size:NSMakeSize(CGImageGetWidth(thumbnail)*scale,CGImageGetHeight(thumbnail)*scale)] autorelease]; CGImageRelease(thumbnail);
                }
            }
            [props release]; CFRelease(source);
        }
    }
    NSTextAttachmentCell *cell=image ? [[[NSTextAttachmentCell alloc] initImageCell:image] autorelease] : [[[NSTextAttachmentCell alloc] initTextCell:[NSString stringWithFormat:@"[%@: could not load]",state[@"alternate"]]] autorelease];
    [attachment setAttachmentCell:cell];
    [_requests removeObjectForKey:@(task.taskIdentifier)];
    [_delegate markupAttachmentChanged:attachment];
}
@end
