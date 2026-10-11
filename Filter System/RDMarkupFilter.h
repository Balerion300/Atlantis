#import "RDAtlantisFilter.h"
#import "RDMarkupParser.h"
#import "RDMarkupImageLoader.h"
@interface RDMarkupFilter : RDAtlantisFilter <RDMarkupDelegate,RDMarkupImageDelegate> {
    RDMarkupParser *_parser;
    RDMarkupImageLoader *_loader;
    NSMutableDictionary *_commands;
}
- (BOOL)activateLink:(NSURL *)url;
@end
