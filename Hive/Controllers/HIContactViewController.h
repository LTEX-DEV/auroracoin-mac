//
//  HIContactViewController.h
//  Hive
//
//  Created by Jakub Suder on 30.08.2013.
//  Copyright (c) 2013 Hive Developers. All rights reserved.
//

#import "HIContact.h"
#import "HIContactTabBarController.h"
#import "HIProfileTabView.h"
#import "HIViewController.h"

/*
 Manages the contact view that shows information about a selected contact. Includes a tab bar and two tabs with
 transactions list and contact's info. Also used for the user's own profile, though in that case the tab bar is
 hidden and only the contact info panel is visible.
 */

@interface HIContactViewController : HIViewController <HIProfileTabBarControllerDelegate>

@property (strong) IBOutlet NSImageView *photoView;
@property (strong) IBOutlet NSTextField *nameLabel;
@property (strong) IBOutlet NSButton *sendBitcoinButton;
@property (strong) IBOutlet HIProfileTabView *tabView;
@property (strong) IBOutlet HIContactTabBarController *tabBarController;
@property (strong) IBOutlet NSView *contentView;

- (instancetype)initWithContact:(HIContact *)aContact;
- (IBAction)sendBitcoinsPressed:(id)sender;

@end
