#import "BackgroundView.h"
#import "StatusItemView.h"

@class PanelController;

@protocol PanelControllerDelegate <NSObject>

- (void)hostAddressListChanged: (NSMutableDictionary *)newHostAddressList;

@optional

- (StatusItemView *)statusItemViewForPanelController:(PanelController *)controller;

@end

#pragma mark -

@interface PanelController : NSWindowController <NSWindowDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate>
{
    BOOL _hasActivePanel;
    __unsafe_unretained BackgroundView *_backgroundView;
    __unsafe_unretained id<PanelControllerDelegate> _delegate;
    __unsafe_unretained NSTextField *_hostField;
    __unsafe_unretained NSButton *_okButton;
    __unsafe_unretained NSTableView *_tableView;
}

@property (nonatomic, unsafe_unretained) IBOutlet BackgroundView *backgroundView;
@property (nonatomic, unsafe_unretained) IBOutlet NSTextField *hostField;
@property (nonatomic, unsafe_unretained) IBOutlet NSButton *okButton;
@property (nonatomic, unsafe_unretained) IBOutlet NSTableView *tableView;
@property (nonatomic, strong) NSMutableDictionary *hostsList;

@property (nonatomic) BOOL hasActivePanel;
@property (nonatomic, unsafe_unretained, readonly) id<PanelControllerDelegate> delegate;

- (id)initWithDelegate:(id<PanelControllerDelegate>)delegate;

- (void)openPanel;
- (void)closePanel;

- (IBAction) okButtonClicked:(id)sender;

@end
