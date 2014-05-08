//
//  HIMainWindowController.h
//  Hive
//
//  Created by Bazyli Zygan on 12.06.2013.
//  Copyright (c) 2013 Hive Developers. All rights reserved.
//

#import <INAppStoreWindow/INAppStoreWindow.h>
#import "HISidebarController.h"
#import "HIViewController.h"

@class HILockScreenViewController;


/*
 Manages the main Hive window, switching between tabs using sidebar buttons etc.
 */

@interface HIMainWindowController : NSWindowController <HISidebarControllerDelegate>

@property (strong) IBOutlet NSView *contentView;
@property (strong) IBOutlet NSButton *sendButton;
@property (strong) IBOutlet HILockScreenViewController *lockScreenController;
@property (strong) IBOutlet HISidebarController *sidebarController;
@property (strong) IBOutlet NSView *networkErrorView;

- (void)switchToPanel:(Class)panelClass;

@end
