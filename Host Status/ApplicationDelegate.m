#import "ApplicationDelegate.h"
#import "MKNetworkKit.h"

#define HOST_ADDRESS @"HOST_ADDRESS_FOR_TRACKING"
#define CHEKC_FREQUECY 5.0

@interface ApplicationDelegate ()

@property (nonatomic, strong) NSString *currentHost;
@property (nonatomic, strong) MKNetworkEngine *netManager;
@property (nonatomic, strong) NSMutableDictionary *serversStatus;

@end

@implementation ApplicationDelegate

@synthesize panelController = _panelController;
@synthesize menubarController = _menubarController;
@synthesize currentHost = _currentHost;
@synthesize netManager = _netManager;
@synthesize serversStatus = _serversStatus;

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

    self.serversStatus = [[NSMutableDictionary alloc] init];

    // Install icon into the menu bar
    self.menubarController = [[MenubarController alloc] init];
    
    NSString *savedHost = [[NSUserDefaults standardUserDefaults] stringForKey:HOST_ADDRESS];
    
    if (savedHost == nil)
    {
        savedHost = @"www.google.com";
    }
    
    self.serversStatus[savedHost] = @YES;

    
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
        
        if (self.netManager != nil)
        {
            self.netManager = nil;
        }
        
        __block id selfRef = self;
        
        NSURL *hostUrl = [NSURL URLWithString:self.currentHost];
        
        self.netManager = [[MKNetworkEngine alloc] initWithHostName:hostUrl.host];
        
        self.netManager.reachabilityChangedHandler = ^(NetworkStatus ns)
        {
            if (ns == NotReachable)
            {                
                self.menubarController.statusItemView.image = [NSImage imageNamed:@"no"];
                
                if ([self.serversStatus[self.currentHost] boolValue] == YES)
                {
                    [selfRef showNotification: @"down again!"];
                }
                
                self.serversStatus[self.currentHost] = @NO;
            }
            else
            {
                [selfRef tryToDownloadSomething];
            }
        };
                        
        [[NSUserDefaults standardUserDefaults] setValue:currentHost forKey:HOST_ADDRESS];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)tryToDownloadSomething
{
    MKNetworkOperation *operationToExecute = [[MKNetworkOperation alloc] initWithURLString:self.currentHost params:nil httpMethod:@"GET"];
    
    [operationToExecute addCompletionHandler:^(MKNetworkOperation *completedOperation)
    {
        self.menubarController.statusItemView.image = [NSImage imageNamed:@"yes"];
        
        if ([self.serversStatus[self.currentHost] boolValue] == NO)
        {
            [self showNotification: @"alive!"];
        }
        
        self.serversStatus[self.currentHost] = @YES;

        [self performSelector:@selector(tryToDownloadSomething) withObject:nil afterDelay:CHEKC_FREQUECY];
    }
    errorHandler:^(MKNetworkOperation *completedOperation, NSError *error)
    {
        self.menubarController.statusItemView.image = [NSImage imageNamed:@"no"];
        
        if ([self.serversStatus[self.currentHost] boolValue] == YES)
        {
            [self showNotification: @"down again!"];
        }
        
        self.serversStatus[self.currentHost] = @NO;

        NSLog (@"Net error: %@", error);
        
        [self performSelector:@selector(tryToDownloadSomething) withObject:nil afterDelay:CHEKC_FREQUECY];
    }];
    
    [self.netManager enqueueOperation:operationToExecute forceReload:YES];
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
