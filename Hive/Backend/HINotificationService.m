#import "HINotificationService.h"

#import "BCClient.h"
#import "HIBackupAdapter.h"
#import "HIBackupManager.h"
#import "HIBitcoinFormatService.h"
#import "HITransaction.h"
#import "NSAlert+Hive.h"

static int KVO_CONTEXT;
static NSString *const HINotificationTypeKey = @"HINotificationTypeKey";
static NSString *const LastBackupsCheckKey = @"LastBackupsCheckKey";
static NSTimeInterval BackupsEnabledNotificationInterval = 7 * 86400;

typedef NS_ENUM(NSInteger, HINotificationType) {
    HINotificationTypeTransaction,
    HINotificationTypeBackup,
};

@interface HINotificationService () <NSUserNotificationCenterDelegate, BCTransactionObserver>
@end

@implementation HINotificationService

#pragma deploymate push "ignored-api-availability"

+ (HINotificationService *)sharedService {
    static HINotificationService *sharedService = nil;
    static dispatch_once_t oncePredicate;

    dispatch_once(&oncePredicate, ^{
        sharedService = [[self class] new];
    });

    return sharedService;
}

- (BOOL)notificationsAvailable {
    return NSClassFromString(@"NSUserNotificationCenter") != nil;
}

- (void)setEnabled:(BOOL)enabled {
    enabled = enabled && self.notificationsAvailable;
    if (!_enabled && enabled) {
        [self enable];
    } else if (_enabled && !enabled) {
        [self disable];
    }
    _enabled = enabled;
}

- (void)enable {
    [NSUserNotificationCenter defaultUserNotificationCenter].delegate = self;
    [[BCClient sharedClient] addTransactionObserver:self];

    for (HIBackupAdapter *adapter in [[HIBackupManager sharedManager] visibleAdapters]) {
        [adapter addObserver:self forKeyPath:@"errorMessage" options:0 context:&KVO_CONTEXT];
    }
}

- (void)disable {
    [[BCClient sharedClient] removeTransactionObserver:self];

    for (HIBackupAdapter *adapter in [[HIBackupManager sharedManager] visibleAdapters]) {
        [adapter removeObserver:self forKeyPath:@"errorMessage" context:&KVO_CONTEXT];
    }
}

- (BOOL)shouldCheckIfBackupsEnabled {
    NSDate *lastCheck = [[NSUserDefaults standardUserDefaults] objectForKey:LastBackupsCheckKey];

    return (!lastCheck || [[NSDate date] timeIntervalSinceDate:lastCheck] >= BackupsEnabledNotificationInterval);
}

- (void)checkIfBackupsEnabled {
    if (![self shouldCheckIfBackupsEnabled]) {
        return;
    }

    [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:LastBackupsCheckKey];

    for (HIBackupAdapter *adapter in [[HIBackupManager sharedManager] visibleAdapters]) {
        if (adapter.enabled) {
            return;
        }
    }

    [self postNoBackupsEnabledNotification];
}

- (void)postNotification:(NSString *)notificationText
                    text:(NSString *)text
        notificationType:(HINotificationType)notificationType {

    NSUserNotification *notification = [NSUserNotification new];
    notification.title = notificationText;
    notification.informativeText = text;
    notification.userInfo = @{
        HINotificationTypeKey: @(notificationType),
    };

    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

#pragma mark - NSUserNotificationCenterDelegate

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center
     shouldPresentNotification:(NSUserNotification *)notification {
    // So we receive notifications even if in the foreground.
    return YES;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center
       didActivateNotification:(NSUserNotification *)notification {

    switch ([notification.userInfo[HINotificationTypeKey] longValue]) {
        case HINotificationTypeTransaction:
            if (self.onTransactionClicked) {
                self.onTransactionClicked();
            }
            break;
        case HINotificationTypeBackup:
            if (self.onBackupErrorClicked) {
                self.onBackupErrorClicked();
            }
            break;
    }
}

#pragma mark - BCTransactionObserver

- (void)transactionAdded:(HITransaction *)transaction {
    if (!transaction.read && transaction.isIncoming) {
        [self postReceivedNotification:transaction];
    }
}

- (void)transactionChangedStatus:(HITransaction *)transaction {
    if (transaction.isOutgoing && transaction.status == HITransactionStatusBuilding) {
        [self postSendConfirmedNotification:transaction];
    } else if (transaction.status == HITransactionStatusDead) {
        [self postCancelledTransactionNotificationForTransaction:transaction];
        [self showCancelledTransactionAlertForTransaction:transaction];
    }
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {

    if (context == &KVO_CONTEXT) {
        HIBackupAdapter *adapter = object;
        if (adapter.errorMessage) {
            [self postBackupErrorNotificationForAdapter:adapter];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


#pragma mark - Notifications

- (void)postReceivedNotification:(HITransaction *)transaction {
    NSString *btc = [[HIBitcoinFormatService sharedService] stringWithUnitForBitcoin:transaction.absoluteAmount];

    [self postNotification:NSLocalizedString(@"You've received Bitcoin", @"Notification of incoming transaction")
                      text:btc
          notificationType:HINotificationTypeTransaction];
}

- (void)postSendConfirmedNotification:(HITransaction *)transaction {
    NSString *btc = [[HIBitcoinFormatService sharedService] stringWithUnitForBitcoin:transaction.absoluteAmount];
    NSString *text = [NSString stringWithFormat:
                      NSLocalizedString(@"You have sent %@.",
                                        @"Notification of confirmed sent transaction (with BTC amount)"),
                      btc];

    [self postNotification:NSLocalizedString(@"Transaction completed", @"Notification of confirmed sent transaction")
                      text:text
          notificationType:HINotificationTypeTransaction];
}

- (void)postBackupErrorNotificationForAdapter:(HIBackupAdapter *)adapter {
    NSString *title = adapter.status == HIBackupStatusFailure ? HIBackupStatusTextFailure : HIBackupStatusTextOutdated;

    [self postNotification:title
                      text:adapter.errorMessage
          notificationType:HINotificationTypeBackup];
}

- (void)postNoBackupsEnabledNotification {
    [self postNotification:NSLocalizedString(@"No backups configured",
                                             @"No backups enabled notification title")
                      text:NSLocalizedString(@"To protect your bitcoins, it's recommended "
                                             @"that you enable at least one type of backup.",
                                             @"No backups enabled notification details")
          notificationType:HINotificationTypeBackup];
}

- (void)postCancelledTransactionNotificationForTransaction:(HITransaction *)transaction {
    [self postNotification:NSLocalizedString(@"Transaction cancelled", @"Notification of cancelled transaction")
                      text:nil
          notificationType:HINotificationTypeTransaction];
}

- (void)showCancelledTransactionAlertForTransaction:(HITransaction *)transaction {
    // this should never happen, and if it happens then something went seriously wrong,
    // so let's make sure the user sees this

    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"LLL d jj:mm a"
                                                           options:0
                                                            locale:[NSLocale  currentLocale]];

    NSString *formattedDate = [formatter stringFromDate:transaction.date];

    NSString *title = NSLocalizedString(@"Transaction from %@ was cancelled.",
                                        @"Alert when transaction was cancelled (with transaction date)");

    NSString *message = NSLocalizedString(@"This can happen because of bugs in the wallet code "
                                          @"or because the transaction was rejected by the network.",
                                          @"Alert details when transaction was cancelled");

    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [NSAlert hiOKAlertWithTitle:[NSString stringWithFormat:title, formattedDate]
                                             message:message];

        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert runModal];
    });
}

#pragma deploymate pop

@end
