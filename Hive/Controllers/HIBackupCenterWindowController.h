//
//  HIBackupCenterWindowController.h
//  Hive
//
//  Created by Jakub Suder on 23.12.2013.
//  Copyright (c) 2013 Hive Developers. All rights reserved.
//

#import "HIKeyObservingWindow.h"

@interface HIBackupCenterWindowController : NSWindowController
    <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate, HIKeyObservingWindowDelegate>

@end
