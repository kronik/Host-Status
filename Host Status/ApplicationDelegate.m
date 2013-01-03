#import "ApplicationDelegate.h"
#import "Reachability.h"

#define HOST_ADDRESS @"HOST_ADDRESS_FOR_TRACKING"

@interface ApplicationDelegate ()
{
    Reachability *reachManager;
}

@property (nonatomic, strong) NSString *currentHost;

@end

@implementation ApplicationDelegate

@synthesize panelController = _panelController;
@synthesize menubarController = _menubarController;
@synthesize currentHost = _currentHost;

#pragma mark -

- (void)dealloc
{
    [_panelController removeObserver:self forKeyPath:@"hasActivePanel"];
}

#pragma mark -

void *kContextActivePanel = &kContextActivePanel;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kContextActivePanel) {
        self.menubarController.hasActiveIcon = self.panelController.hasActivePanel;
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];

    // Install icon into the menu bar
    self.menubarController = [[MenubarController alloc] init];
    
    NSString *savedHost = [[NSUserDefaults standardUserDefaults] stringForKey:HOST_ADDRESS];
    
    if (savedHost == nil)
    {
        savedHost = @"www.google.com";
    }
    
    self.currentHost = savedHost;
    
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(reachabilityChanged:)
//                                                 name:kReachabilityChangedNotification
//                                               object:nil];
    
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

- (void)showNotification:(NSString*)status
{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    
    notification.title = @"Server status changed.";
    notification.subtitle = [NSString stringWithFormat: @"Server is %@", status];
    notification.soundName = NSUserNotificationDefaultSoundName;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (void)setCurrentHost:(NSString *)currentHost
{
    if ([_currentHost isEqualToString: currentHost] == NO)
    {
        _currentHost = currentHost;
        
        if (reachManager != nil)
        {
            [reachManager stopNotifier];
        }
        
        __block id selfRef = self;
        
        reachManager = [Reachability reachabilityWithHostname: self.currentHost];
        
        reachManager.reachableBlock = ^(Reachability * reachability)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.menubarController.statusItemView.image = [NSImage imageNamed:@"yes"];
                
                [selfRef showNotification: @"alive!"];
            });
        };
        
        reachManager.unreachableBlock = ^(Reachability * reachability)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.menubarController.statusItemView.image = [NSImage imageNamed:@"no"];
                
                [selfRef showNotification: @"down again!"];
            });
        };
        
        [reachManager startNotifier];
        
        [[NSUserDefaults standardUserDefaults] setValue:currentHost forKey:HOST_ADDRESS];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    // Explicitly remove the icon from the menu bar
    self.menubarController = nil;
    return NSTerminateNow;
}

#pragma mark - Actions

- (IBAction)togglePanel:(id)sender
{
    self.menubarController.hasActiveIcon = !self.menubarController.hasActiveIcon;
    self.panelController.hasActivePanel = self.menubarController.hasActiveIcon;
}

#pragma mark - Public accessors

- (PanelController *)panelController
{
    if (_panelController == nil) {
        _panelController = [[PanelController alloc] initWithDelegate:self];
        [_panelController addObserver:self forKeyPath:@"hasActivePanel" options:0 context:kContextActivePanel];
    }
    
    _panelController.hostField.stringValue = self.currentHost;
    return _panelController;
}

- (void)hostAddressChanged: (NSString *)newHostAddress
{
    self.currentHost = newHostAddress;
    
    [self togglePanel:nil];
}

#pragma mark - PanelControllerDelegate

- (StatusItemView *)statusItemViewForPanelController:(PanelController *)controller
{
    return self.menubarController.statusItemView;
}

-(void)reachabilityChanged:(NSNotification*)note
{
    Reachability * reach = [note object];
    
    if([reach isReachable])
    {
        self.menubarController.statusItemView.image = [NSImage imageNamed:@"yes"];
    }
    else
    {
        self.menubarController.statusItemView.image = [NSImage imageNamed:@"no"];
    }
}


@end
