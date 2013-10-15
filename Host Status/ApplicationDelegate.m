#import "ApplicationDelegate.h"
#import "MKNetworkKit.h"

#define HOST_ADDRESS_LIST @"HOST_ADDRESS_LIST_FOR_TRACKING"
#define CHEKC_FREQUECY 5.0

@interface ApplicationDelegate ()

@property (nonatomic, strong) MKNetworkEngine *netManager;
@property (nonatomic, strong) NSDate *lastUpdateTime;
@property (nonatomic, strong) NSMutableDictionary *hosts;

@end

@implementation ApplicationDelegate

@synthesize panelController = _panelController;
@synthesize menubarController = _menubarController;
@synthesize netManager = _netManager;
@synthesize lastUpdateTime = _lastUpdateTime;
@synthesize hosts = _hosts;

#pragma mark -

- (void)dealloc {
    [_panelController removeObserver:self forKeyPath:@"hasActivePanel"];
}

#pragma mark -

void *kContextActivePanel = &kContextActivePanel;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == kContextActivePanel) {
        self.menubarController.hasActiveIcon = self.panelController.hasActivePanel;
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];

    self.lastUpdateTime = [NSDate dateWithTimeIntervalSince1970: 0];

    [[NSUserDefaults standardUserDefaults] setValue:[NSMutableDictionary new] forKey:HOST_ADDRESS_LIST];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // Install icon into the menu bar
    self.menubarController = [[MenubarController alloc] init];
    
    self.hosts = [[[NSUserDefaults standardUserDefaults] objectForKey:HOST_ADDRESS_LIST] mutableCopy];
    
    if (self.hosts == nil) {
        self.hosts = [NSMutableDictionary new];
        self.hosts [@"http://www.google.com"] = @YES;
    }
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    return YES;
}

- (void)showNotification:(NSString*)status {
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    
    notification.title = @"Server status changed.";
    notification.subtitle = [NSString stringWithFormat: @"Server is %@", status];
    notification.soundName = NSUserNotificationDefaultSoundName;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (void)setHosts:(NSMutableDictionary *)hosts {

    @synchronized (self) {
        _hosts = hosts;
        
        if (self.netManager == nil) {
            self.netManager = [[MKNetworkEngine alloc] initWithHostName:@"http://google.com"];
        }
            
        __block ApplicationDelegate *selfRef = self;

//        self.netManager.reachabilityChangedHandler = ^(NetworkStatus ns) {
//            if (ns == NotReachable) {
//                selfRef.menubarController.statusItemView.image = [NSImage imageNamed:@"no"];
//
//                @synchronized (selfRef) {
//                    for (NSString *host in selfRef.hosts) {
//                        selfRef.hosts [host] = @NO;
//                    }
//                }
//            } else {
//                
//                [selfRef tryToDownloadSomething];
//            }
//        };
        
        [selfRef tryToDownloadSomething];
        
        [[NSUserDefaults standardUserDefaults] setValue:self.hosts forKey:HOST_ADDRESS_LIST];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)tryToDownloadSomething {
    // Wait until table will be reloaded
    NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate: self.lastUpdateTime];
    
    if (interval > 3) {
        self.lastUpdateTime = [NSDate date];
    } else {
        return;
    }
    
    __block ApplicationDelegate *selfRef = self;
    @synchronized (self) {
        for (NSString *host in self.hosts) {

            MKNetworkOperation *operationToExecute = [[MKNetworkOperation alloc] initWithURLString:host params:nil httpMethod:@"GET"];
            
            [operationToExecute addCompletionHandler:^(MKNetworkOperation *completedOperation) {

                selfRef.hosts [host] = @YES;
                BOOL isAllAlive = YES;
                
                for (NSString *checkHost in self.hosts) {
                    if ([selfRef.hosts[host] boolValue] == NO) {
                        isAllAlive = NO;
                        break;
                    }
                }
                
                if (isAllAlive == NO) {
                    selfRef.menubarController.statusItemView.image = [NSImage imageNamed:@"no"];
                    [self showNotification: @"down again!"];
                } else {
                    selfRef.menubarController.statusItemView.image = [NSImage imageNamed:@"yes"];
                }
                
                [self performSelector:@selector(tryToDownloadSomething) withObject:nil afterDelay:CHEKC_FREQUECY];
            } errorHandler:^(MKNetworkOperation *completedOperation, NSError *error) {
                selfRef.menubarController.statusItemView.image = [NSImage imageNamed:@"no"];
                
                selfRef.hosts [host] = @NO;

                NSLog (@"Net error: %@", error);
                
                [self performSelector:@selector(tryToDownloadSomething) withObject:nil afterDelay:CHEKC_FREQUECY];
            }];
            
            [self.netManager enqueueOperation:operationToExecute forceReload:YES];
        }
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    // Explicitly remove the icon from the menu bar
    self.menubarController = nil;
    return NSTerminateNow;
}

#pragma mark - Actions

- (IBAction)togglePanel:(id)sender {
    self.menubarController.hasActiveIcon = !self.menubarController.hasActiveIcon;
    self.panelController.hasActivePanel = self.menubarController.hasActiveIcon;
}

#pragma mark - Public accessors

- (PanelController *)panelController {
    if (_panelController == nil) {
        _panelController = [[PanelController alloc] initWithDelegate:self];
        [_panelController addObserver:self forKeyPath:@"hasActivePanel" options:0 context:kContextActivePanel];
    }
    
    for (NSString *host in self.hosts) {
        _panelController.hostField.stringValue = host;
        break;
    }
    
    _panelController.hostsList = self.hosts;
    
    return _panelController;
}

- (void)hostAddressListChanged: (NSMutableDictionary *)newHostAddressList {
    
    self.hosts = newHostAddressList;
    
    //[self togglePanel:nil];
}

#pragma mark - PanelControllerDelegate

- (StatusItemView *)statusItemViewForPanelController:(PanelController *)controller {
    return self.menubarController.statusItemView;
}

-(void)reachabilityChanged:(NSNotification*)note {
    Reachability * reach = [note object];
    
    if ([reach isReachable]) {
        self.menubarController.statusItemView.image = [NSImage imageNamed:@"yes"];
    } else {
        self.menubarController.statusItemView.image = [NSImage imageNamed:@"no"];
    }
}

@end
