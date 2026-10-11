#import "WorldMarkupEditor.h"
@implementation WorldMarkupEditor
- (id)initWithWorld:(RDAtlantisWorldPreferences *)prefs forCharacter:(NSString *)character {
    if ((self=[super initWithWorld:prefs forCharacter:character])) {
        _view=[[NSView alloc] initWithFrame:NSMakeRect(0,0,560,330)];
        NSMutableArray *buttons=[NSMutableArray array];
        NSArray *labels=@[@"Enable Pueblo",@"Enable MXP (common display tags)",@"Load inline images from the game",@"Allow clickable game commands"];
        NSArray *keys=@[@"atlantis.pueblo.enabled",@"atlantis.mxp.enabled",@"atlantis.markup.images",@"atlantis.markup.commands"];
        for (NSUInteger i=0;i<keys.count;i++) {
            NSButton *button=[[[NSButton alloc] initWithFrame:NSMakeRect(24,270-i*38,510,28)] autorelease];
            [button setButtonType:NSSwitchButton]; button.title=labels[i]; button.target=self; button.action=@selector(changed:);
            id value=[prefs preferenceForKey:keys[i] withCharacter:character]; button.state=value?([value boolValue]?NSOnState:NSOffState):(i==3?NSOnState:NSOffState);
            [_view addSubview:button]; [buttons addObject:button];
        }
        _buttons=[buttons copy];
        if (character) {
            _inherit=[[NSButton alloc] initWithFrame:NSMakeRect(24,112,510,28)]; [_inherit setButtonType:NSSwitchButton]; _inherit.title=@"Use world settings"; _inherit.target=self; _inherit.action=@selector(changed:);
            BOOL inherited=YES; for (NSString *key in keys) if ([prefs preferenceForKey:key withCharacter:character fallback:NO]) inherited=NO;
            _inherit.state=inherited?NSOnState:NSOffState; [_view addSubview:_inherit];
        }
        NSTextField *hint=[[[NSTextField alloc] initWithFrame:NSMakeRect(24,20,510,82)] autorelease]; hint.editable=NO; hint.bezeled=NO; hint.drawsBackground=NO;
        hint.stringValue=@"Reconnect after changing Pueblo or MXP. Both are off by default. Images load asynchronously; click a game link to send its command. No commands execute just by receiving markup.\nMXP preview: standard display tags; custom elements and entities are not yet supported."; [_view addSubview:hint];
        [self updateEnabled];
    } return self;
}
- (void)updateEnabled { for (NSButton *button in _buttons) button.enabled=(!_inherit || _inherit.state!=NSOnState); }
- (void)changed:(id)sender { [self updateEnabled]; [self noteUpdate]; }
- (NSString *)configTabName { return @"Pueblo and MXP"; }
- (NSView *)configTabView { return _view; }
- (void)finalCommit {
    if (!_buttons) return;
    NSArray *keys=@[@"atlantis.pueblo.enabled",@"atlantis.mxp.enabled",@"atlantis.markup.images",@"atlantis.markup.commands"];
    [[self preferences] beginBulk];
    for (NSUInteger i=0;i<keys.count;i++) {
        if (_inherit && _inherit.state==NSOnState) [[self preferences] removePreferenceForKey:keys[i] withCharacter:[self character]];
        else [[self preferences] setPreference:@([_buttons[i] state]==NSOnState) forKey:keys[i] withCharacter:[self character]];
    } [[self preferences] endBulk];
}
- (void)dealloc { [self finalCommit]; [_buttons release]; _buttons=nil; [_inherit release]; [_view release]; [super dealloc]; }
@end
