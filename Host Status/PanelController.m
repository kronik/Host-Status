#import "PanelController.h"
#import "BackgroundView.h"
#import "StatusItemView.h"
#import "MenubarController.h"

#define OPEN_DURATION .15
#define CLOSE_DURATION .1

#define SEARCH_INSET 17

#define POPUP_HEIGHT 234
#define PANEL_WIDTH 280
#define MENU_ANIMATION_DURATION .1

@interface PanelController ()

@property (nonatomic, strong) NSTimer *updateTimer;

@end

#pragma mark -

@implementation PanelController

@synthesize backgroundView = _backgroundView;
@synthesize delegate = _delegate;
@synthesize hostField = _hostField;
@synthesize okButton = _okButton;
@synthesize tableView = _tableView;
@synthesize hostsList = _hostsList;
@synthesize updateTimer = _updateTimer;

#pragma mark -

- (id)initWithDelegate:(id<PanelControllerDelegate>)delegate {
    self = [super initWithWindowNibName:@"Panel"];
    
    if (self != nil) {
        _delegate = delegate;
    }
    return self;
}

- (void)dealloc {
    [self.updateTimer invalidate];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];    
}

#pragma mark -

- (void)awakeFromNib {
    [super awakeFromNib];
    
    // Make a fully skinned panel
    NSPanel *panel = (id)[self window];
    [panel setAcceptsMouseMovedEvents:YES];
    [panel setLevel:NSPopUpMenuWindowLevel];
    [panel setOpaque:NO];
    [panel setBackgroundColor:[NSColor clearColor]];
    
    // Resize panel
    NSRect panelRect = [[self window] frame];
    panelRect.size.height = POPUP_HEIGHT;
    [[self window] setFrame:panelRect display:NO];
}

#pragma mark - Public accessors

- (BOOL)hasActivePanel {
    return _hasActivePanel;
}

- (void)setHasActivePanel:(BOOL)flag {
    if (_hasActivePanel != flag) {
        _hasActivePanel = flag;
        
        if (_hasActivePanel) {
            [self openPanel];
        } else {
            [self closePanel];
        }
    }
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification {
    self.hasActivePanel = NO;
}

- (void)windowDidResignKey:(NSNotification *)notification; {
//    if ([[self window] isVisible]) {
//        self.hasActivePanel = NO;
//    }
}

- (void)windowDidResize:(NSNotification *)notification {
    NSWindow *panel = [self window];
    NSRect statusRect = [self statusRectForWindow:panel];
    NSRect panelRect = [panel frame];
    
    CGFloat statusX = roundf(NSMidX(statusRect));
    CGFloat panelX = statusX - NSMinX(panelRect);
    
    self.backgroundView.arrowX = panelX;
    
    NSRect searchRect = [self.hostField frame];
    searchRect.size.width = NSWidth([self.backgroundView bounds]) - SEARCH_INSET * 2 - 40;
    searchRect.origin.x = SEARCH_INSET;
    searchRect.origin.y = NSHeight([self.backgroundView bounds]) - ARROW_HEIGHT - SEARCH_INSET - NSHeight(searchRect);
    
    if (NSIsEmptyRect(searchRect)) {
        [self.hostField setHidden:YES];
    } else {
        [self.hostField setFrame:searchRect];
        [self.hostField setHidden:NO];
    }
    
    NSRect textRect = [self.okButton frame];
    textRect.size.width = 40;
    textRect.origin.x = NSWidth([self.backgroundView bounds]) - SEARCH_INSET * 2 - 15;
    textRect.origin.y = NSHeight([self.backgroundView bounds]) - ARROW_HEIGHT - SEARCH_INSET - NSHeight(searchRect);
    
    if (NSIsEmptyRect(textRect)) {
        [self.okButton setHidden:YES];
    } else {
        [self.okButton setFrame:textRect];
        [self.okButton setHidden:NO];
    }
}

#pragma mark - Keyboard

- (void)cancelOperation:(id)sender {
    self.hasActivePanel = NO;
}

- (IBAction)okButtonClicked:(id)sender {
    [self saveAndUpdate];
}

- (void)saveAndUpdate {
    //[self.delegate hostAddressChanged: self.hostField.stringValue];
    
    NSString *host = self.hostField.stringValue;
    
    self.hostField.stringValue = @"";
    
    if (host.length > 0) {
        if ([host rangeOfString:@"http"].location == NSNotFound) {
            host = [NSString stringWithFormat:@"http://%@", host];
        }
        self.hostsList [host] = @NO;
    }
    
    [self.delegate hostAddressListChanged:self.hostsList];
    
    [self.tableView reloadData];
    //[self closePanel];
}

-(void)controlTextDidEndEditing:(NSNotification *)notification {
    // See if it was due to a return
    if ( [[[notification userInfo] objectForKey:@"NSTextMovement"] intValue] == NSReturnTextMovement ) {
        [self saveAndUpdate];
    }
}

#pragma mark - Public methods

- (NSRect)statusRectForWindow:(NSWindow *)window {
    NSRect screenRect = [[[NSScreen screens] objectAtIndex:0] frame];
    NSRect statusRect = NSZeroRect;
    
    StatusItemView *statusItemView = nil;
    
    if ([self.delegate respondsToSelector:@selector(statusItemViewForPanelController:)]) {
        statusItemView = [self.delegate statusItemViewForPanelController:self];
    }
    
    if (statusItemView) {
        statusRect = statusItemView.globalRect;
        statusRect.origin.y = NSMinY(statusRect) - NSHeight(statusRect);
    } else {
        statusRect.size = NSMakeSize(STATUS_ITEM_VIEW_WIDTH, [[NSStatusBar systemStatusBar] thickness]);
        statusRect.origin.x = roundf((NSWidth(screenRect) - NSWidth(statusRect)) / 2);
        statusRect.origin.y = NSHeight(screenRect) - NSHeight(statusRect) * 2;
    }
    
    return statusRect;
}

- (void)openPanel {
    NSWindow *panel = [self window];
    
    NSRect screenRect = [[[NSScreen screens] objectAtIndex:0] frame];
    NSRect statusRect = [self statusRectForWindow:panel];

    NSRect panelRect = [panel frame];
    panelRect.size.width = PANEL_WIDTH;
    panelRect.origin.x = roundf(NSMidX(statusRect) - NSWidth(panelRect) / 2);
    panelRect.origin.y = NSMaxY(statusRect) - NSHeight(panelRect);
    
    if (NSMaxX(panelRect) > (NSMaxX(screenRect) - ARROW_HEIGHT))
        panelRect.origin.x -= NSMaxX(panelRect) - (NSMaxX(screenRect) - ARROW_HEIGHT);
    
    [NSApp activateIgnoringOtherApps:NO];
    [panel setAlphaValue:0];
    [panel setFrame:statusRect display:YES];
    [panel makeKeyAndOrderFront:nil];
    
    NSTimeInterval openDuration = OPEN_DURATION;
    
    NSEvent *currentEvent = [NSApp currentEvent];
    
    if ([currentEvent type] == NSLeftMouseDown) {
        NSUInteger clearFlags = ([currentEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask);
        BOOL shiftPressed = (clearFlags == NSShiftKeyMask);
        BOOL shiftOptionPressed = (clearFlags == (NSShiftKeyMask | NSAlternateKeyMask));
        
        if (shiftPressed || shiftOptionPressed) {
            openDuration *= 10;
            
            if (shiftOptionPressed)
                NSLog(@"Icon is at %@\n\tMenu is on screen %@\n\tWill be animated to %@",
                      NSStringFromRect(statusRect), NSStringFromRect(screenRect), NSStringFromRect(panelRect));
        }
    }
    
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:openDuration];
    [[panel animator] setFrame:panelRect display:YES];
    [[panel animator] setAlphaValue:1];
    [NSAnimationContext endGrouping];
    
    //[panel performSelector:@selector(makeFirstResponder:) withObject:self.hostField afterDelay:openDuration];
}

- (void)closePanel {
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:CLOSE_DURATION];
    [[[self window] animator] setAlphaValue:0];
    [NSAnimationContext endGrouping];
    
    dispatch_after(dispatch_walltime(NULL, NSEC_PER_SEC * CLOSE_DURATION * 2), dispatch_get_main_queue(), ^{
        
        [self.window orderOut:nil];
    });
}

- (void)setHostsList:(NSMutableDictionary *)hostsList {
    _hostsList = hostsList;// [@{@"www.ay.ru" : @YES, @"www.ayadf.ru" : @YES} mutableCopy];
    
    [self.tableView reloadData];
    
    if (self.updateTimer == nil) {
        self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateTableView) userInfo:nil repeats:YES];
    }
}

- (void)updateTableView {
    [self.tableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return self.hostsList.count;
}
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex {
    int index = 0;
    NSString *keyForCell = @"";
    
    for (NSString *host in self.hostsList) {
        if (index == rowIndex) {
            keyForCell = host;
            break;
        } else {
            index++;
        }
    }
    
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    
    // Since this is a single-column table view, this would not be necessary.
    // But it's a good practice to do it in order by remember it when a table is multicolumn.
    if ( [tableColumn.identifier isEqualToString:@"StatusColumn"] ) {
        cellView.imageView.image = [self.hostsList[keyForCell] boolValue] ? [NSImage imageNamed:@"yes"] : [NSImage imageNamed:@"no"];
        
//        keyForCell = [keyForCell stringByReplacingOccurrencesOfString:@"http://" withString:@""];
//        keyForCell = [keyForCell stringByReplacingOccurrencesOfString:@"https://" withString:@""];

        cellView.textField.stringValue = keyForCell;
        
        return cellView;
    }
    
    return cellView;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
}

- (NSCell*)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return nil;
}

@end
