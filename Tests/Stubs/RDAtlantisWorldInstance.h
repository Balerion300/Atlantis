#import <Cocoa/Cocoa.h>
enum { AtlantisServerMud=1, AtlantisServerIRE=2 };
// Test-only network sink. The app builds against the real world header.
@interface RDAtlantisWorldInstance : NSObject {
@public BOOL mxp; NSMutableData *sent; NSUInteger starts; BOOL active;
}
- (id)preferenceForKey:(NSString *)key;
- (void)sendDataRaw:(NSData *)data;
- (int)mainScreenWidth;
- (int)mainScreenHeight;
- (NSStringEncoding)stringEncoding;
- (void)setStringEncoding:(NSStringEncoding)encoding;
- (void)handleStatusOutput:(NSString *)text;
- (void)compress:(BOOL)enabled;
- (void)addBytesToCompress:(NSData *)data;
@end
