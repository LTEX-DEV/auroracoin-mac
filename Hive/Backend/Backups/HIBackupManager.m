//
//  HIBackupManager.m
//  Hive
//
//  Created by Jakub Suder on 23.12.2013.
//  Copyright (c) 2013 Hive Developers. All rights reserved.
//

#import "BCClient.h"
#import "HIBackupAdapter.h"
#import "HIBackupManager.h"
#import "HIDropboxBackup.h"
#import "HIGoogleDriveBackup.h"
#import "HILocalBackup.h"
#import "HITimeMachineBackup.h"

@interface HIBackupManager ()

@property (nonatomic, assign) BOOL initialized;

@end


@implementation HIBackupManager

+ (HIBackupManager *)sharedManager {
    static HIBackupManager *_sharedManager = nil;
    static dispatch_once_t oncePredicate;

    dispatch_once(&oncePredicate, ^{
        _sharedManager = [[self alloc] init];
    });

    return _sharedManager;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        _allAdapters = @[
                         [HIDropboxBackup new],
                         [HIGoogleDriveBackup new],
                         [HILocalBackup new],
                         [HITimeMachineBackup new],
                       ];

        _visibleAdapters = [_allAdapters filteredArrayUsingPredicate:
                            [NSPredicate predicateWithFormat:@"isVisible = YES"]];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onPasswordChange)
                                                     name:BCClientPasswordChangedNotification
                                                   object:nil];

        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@selector(onWakeUp)
                                                                   name:NSWorkspaceDidWakeNotification
                                                                 object:nil];
    }

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

- (void)resetSettings {
    [HIBackupAdapter resetBackupSettings];
}

- (void)initializeAdapters {
    if (!self.initialized) {
        NSDictionary *settings = [HIBackupAdapter backupSettings];

        for (HIBackupAdapter *adapter in self.allAdapters) {
            if (!settings[adapter.name]) {
                adapter.enabled = [adapter isEnabledByDefault];
            }
        }

        [[NSUserDefaults standardUserDefaults] synchronize];

        self.initialized = YES;
    }
}

- (void)performBackups {
    [self.allAdapters makeObjectsPerformSelector:@selector(updateStatusIfEnabled)];
    [self.allAdapters makeObjectsPerformSelector:@selector(performBackupIfEnabled)];
}

- (void)onPasswordChange {
    [self performBackups];
}

- (void)onWakeUp {
    [self performBackups];
}

@end
