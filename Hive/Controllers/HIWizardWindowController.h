//
//  HIWizardViewController.h
//  Hive
//
//  Created by Nikolaj Schumacher on 2014-01-12.
//  Copyright (c) 2014 Hive Developers. All rights reserved.
//

@class HIWizardViewController;

/*
 General multi-page wizard.
 */

@interface HIWizardWindowController : NSWindowController

@property (nonatomic, copy) NSArray *viewControllers;
@property (nonatomic, copy) void (^onCompletion)();
@property (nonatomic, readonly) HIWizardViewController *currentViewController;

@end
