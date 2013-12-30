//
//  HITimeMachineBackup.m
//  Hive
//
//  Created by Jakub Suder on 23.12.2013.
//  Copyright (c) 2013 Hive Developers. All rights reserved.
//

#import "HITimeMachineBackup.h"

static const NSTimeInterval RecentBackupLimit = 86400 * 30; // 30 days

NSString * const HITimeMachineBackupError = @"HITimeMachineBackupError";
const NSInteger HITimeMachineBackupDisabled = -1;
const NSInteger HITimeMachineBackupPathExcluded = -2;


@implementation HITimeMachineBackup

#pragma mark - Superclass method overrides

- (NSString *)name {
    return @"time_machine";
}

- (NSString *)displayedName {
    return @"Time Machine";
}

- (NSImage *)icon {
    return [[NSImage alloc] initWithContentsOfFile:@"/Applications/Time Machine.app/Contents/Resources/backup.icns"];
}

- (BOOL)isEnabledByDefault {
    return YES;
}

- (BOOL)needsToBeConfigured {
    return NO;
}

- (void)updateStatus {
    if (!self.enabled) {
        self.status = HIBackupStatusDisabled;
        self.error = nil;
        self.lastBackupDate = nil;
        return;
    }

    NSDictionary *settings = [self timeMachineSettings];
    BOOL backupsEnabled = [settings[@"AutoBackup"] boolValue];
    self.lastBackupDate = [settings[@"Destinations"][0][@"SnapshotDates"] lastObject];

    // TODO: record last change date in the wallet file
    NSDate *lastWalletChange = [NSDate distantPast];

    if ([self isExcludedFromBackup]) {
        self.status = HIBackupStatusFailure;
        self.error = BackupError(HITimeMachineBackupError, HITimeMachineBackupPathExcluded,
                                 @"Hive directory is excluded from Time Machine backup");
        return;
    }

    BOOL updatedRecently = self.lastBackupDate &&
        ([[NSDate date] timeIntervalSinceDate:self.lastBackupDate] < RecentBackupLimit);

    BOOL afterLastWalletChange = [self.lastBackupDate isGreaterThan:lastWalletChange];

    if (backupsEnabled && updatedRecently) {
        self.error = nil;

        if (afterLastWalletChange) {
            // everything's fresh
            self.status = HIBackupStatusUpToDate;
        } else {
            // we don't have a backup, but we should have one soon
            self.status = HIBackupStatusWaiting;
        }
    } else if (backupsEnabled) { // && !updatedRecently
        self.error = nil;

        if (afterLastWalletChange) {
            // we have a backup, but we probably won't have another
            self.status = HIBackupStatusOutdated;
        } else {
            // we don't have a backup and we probably won't have one
            self.status = HIBackupStatusFailure;
        }
    } else { // !backupsEnabled
        self.error = BackupError(HITimeMachineBackupError, HITimeMachineBackupDisabled,
                                 @"Time Machine is disabled in System Preferences");

        if (afterLastWalletChange) {
            // we have a backup, but we won't have another
            self.status = HIBackupStatusOutdated;
        } else {
            // we don't have a backup and we won't have one
            self.status = HIBackupStatusFailure;
        }
    }
}


#pragma mark - Helpers for checking Time Machine status

- (NSDictionary *)timeMachineSettings {
    NSURL *library = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory
                                                             inDomains:NSLocalDomainMask] firstObject];
    NSURL *preferences = [library URLByAppendingPathComponent:@"Preferences"];
    NSURL *settingsFile = [preferences URLByAppendingPathComponent:@"com.apple.TimeMachine.plist"];
    NSData *settingsData = [NSData dataWithContentsOfURL:settingsFile];

    return [NSPropertyListSerialization propertyListWithData:settingsData options:0 format:NULL error:NULL];
}

- (BOOL)isExcludedFromBackup {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/tmutil";
    task.arguments = @[@"isexcluded", [[[NSApp delegate] applicationFilesDirectory] path]];
    task.standardOutput = [NSPipe pipe];

    [task launch];

    NSData *outputData = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];

    return ([output rangeOfString:@"[Included]"].location == NSNotFound);
}

@end