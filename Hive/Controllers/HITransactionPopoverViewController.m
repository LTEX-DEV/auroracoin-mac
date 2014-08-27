//
//  HITransactionPopoverViewController.m
//  Hive
//
//  Created by Jakub Suder on 11/08/14.
//  Copyright (c) 2014 Hive Developers. All rights reserved.
//

#import "BCClient.h"
#import "HIBitcoinFormatService.h"
#import "HICurrencyFormatService.h"
#import "HITransaction.h"
#import "HITransactionPopoverViewController.h"
#import "NSView+Hive.h"

@interface HITransactionPopoverViewController () <NSPopoverDelegate>

@property (weak) IBOutlet NSTextField *transactionIdField;
@property (weak) IBOutlet NSTextField *statusField;
@property (weak) IBOutlet NSTextField *confirmationsField;

@property (weak) IBOutlet NSBox *separatorAboveMetadataFields;
@property (weak) IBOutlet NSTextField *amountField;
@property (weak) IBOutlet NSTextField *exchangeRateField;
@property (weak) IBOutlet NSTextField *recipientField;
@property (weak) IBOutlet NSTextField *detailsField;
@property (weak) IBOutlet NSTextField *targetAddressField;
@property (weak) IBOutlet NSTextField *targetAddressLabel;

@property (strong) HITransaction *transaction;
@property (strong) NSDictionary *transactionData;

@end

@implementation HITransactionPopoverViewController

- (instancetype)initWithTransaction:(HITransaction *)transaction {
    self = [super initWithNibName:self.className bundle:[NSBundle mainBundle]];

    if (self) {
        self.transaction = transaction;
    }

    return self;
}

- (NSPopover *)createPopover {
    NSPopover *popover = [[NSPopover alloc] init];
    popover.contentViewController = self;
    popover.delegate = self;
    popover.behavior = NSPopoverBehaviorTransient;
    return popover;
}

- (void)awakeFromNib {
    if (self.transaction.id) {
        self.transactionData = [[BCClient sharedClient] transactionDefinitionWithHash:self.transaction.id];
    }

    self.transactionIdField.stringValue = self.transaction.id ?: @"?";
    self.confirmationsField.stringValue = [self confirmationSummary];
    self.statusField.stringValue = [self transactionStatus];
    self.amountField.stringValue = [self amountSummary];

    if (self.transaction.fiatCurrency && self.transaction.fiatRate) {
        self.exchangeRateField.stringValue = [self exchangeRateSummary];
    } else {
        [self hideField:self.exchangeRateField];
    }

    if (self.transaction.label) {
        self.recipientField.stringValue = self.transaction.label;
    } else {
        [self hideField:self.recipientField];
    }

    if (self.transaction.details) {
        self.detailsField.stringValue = self.transaction.details;
    } else {
        [self hideField:self.detailsField];
    }

    // a little hax to include both variants in the XIB's strings file instead of Localizable.strings -
    // one variant is the default text and the other is stored in the placeholder string
    if (self.transaction.direction == HITransactionDirectionIncoming) {
        self.targetAddressLabel.stringValue = [self.targetAddressLabel.cell placeholderString];
    }

    self.targetAddressField.stringValue = self.transaction.targetAddress ?:
                                          [[BCClient sharedClient] walletHash] ?:
                                          @"?";
}

- (void)hideField:(NSTextField *)field {
    // views have tags in pairs, 101+102, 103+104 etc.
    NSInteger fieldTag = field.tag;
    NSInteger labelTag = fieldTag - 1;
    NSAssert(fieldTag > 100, @"Field must have a tag above 100.");
    NSAssert(fieldTag % 2 == 0, @"The value part of the field must have an even tag.");

    NSView *label = [self.view viewWithTag:labelTag];
    NSAssert(label != nil, @"Label view must exist");

    // hide the label+value pair
    [field setHidden:YES];
    [label setHidden:YES];

    // remove their constraints
    [self.view hiRemoveConstraintsMatchingSubviews:^BOOL(NSArray *views) {
        return [views containsObject:label] || [views containsObject:field];
    }];

    // connect the previous field to the next field
    NSView *previousField = field;
    while (previousField && previousField.isHidden) {
        previousField = [self.view viewWithTag:(previousField.tag - 2)];
    }

    NSView *nextLabel = label;
    while (nextLabel && nextLabel.isHidden) {
        nextLabel = [self.view viewWithTag:(nextLabel.tag + 2)];
    }

    NSView *separator = self.separatorAboveMetadataFields;

    NSString *constraintFormat;
    NSDictionary *viewDictionary;

    if (!previousField) {
        viewDictionary = NSDictionaryOfVariableBindings(separator, nextLabel);
        constraintFormat = @"V:[separator]-[nextLabel]";
    } else if (!nextLabel) {
        viewDictionary = NSDictionaryOfVariableBindings(previousField);
        constraintFormat = @"V:[previousField]-|";
    } else {
        viewDictionary = NSDictionaryOfVariableBindings(previousField, nextLabel);
        constraintFormat = @"V:[previousField]-[nextLabel]";
    }

    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:constraintFormat
                                                                      options:0
                                                                      metrics:nil
                                                                        views:viewDictionary]];
}

- (NSString *)transactionStatus {
    switch (self.transaction.status) {
        case HITransactionStatusUnknown:
            return NSLocalizedString(@"Not broadcasted yet",
                                     @"Status for transaction not sent to any peers in transaction popup");

        case HITransactionStatusPending: {
            NSInteger peers = [self.transactionData[@"peers"] integerValue];

            if (peers == 0) {
                return NSLocalizedString(@"Not broadcasted yet",
                                         @"Status for transaction not sent to any peers in transaction popup");
            } else {
                return NSLocalizedString(@"Waiting for confirmation",
                                         @"Status for transaction sent to some peers in transaction popup");
            }
        }

        case HITransactionStatusBuilding:
            return NSLocalizedString(@"Confirmed",
                                     @"Status for transaction included in a block in transaction popup");

        case HITransactionStatusDead:
            return NSLocalizedString(@"Rejected by the network",
                                     @"Status for transaction removed from the main blockchain in transaction popup");
    }
}

- (NSString *)confirmationSummary {
    NSInteger confirmations = [self.transactionData[@"confirmations"] integerValue];

    if (confirmations > 100) {
        return @"100+";
    } else {
        return [NSString stringWithFormat:@"%ld", confirmations];
    }
}

- (NSString *)amountSummary {
    satoshi_t satoshiAmount = self.transaction.absoluteAmount;
    NSString *btcAmount = [[HIBitcoinFormatService sharedService] stringForBitcoin:satoshiAmount withFormat:@"BTC"];

    if (self.transaction.fiatCurrency && self.transaction.fiatAmount) {
        HICurrencyFormatService *fiatFormatter = [HICurrencyFormatService sharedService];
        NSString *fiatAmount = [fiatFormatter stringWithUnitForValue:self.transaction.fiatAmount
                                                          inCurrency:self.transaction.fiatCurrency];

        return [NSString stringWithFormat:@"%@ BTC (%@)", btcAmount, fiatAmount];
    } else {
        return [NSString stringWithFormat:@"%@ BTC", btcAmount];
    }
}

- (NSString *)exchangeRateSummary {
    HICurrencyFormatService *fiatFormatter = [HICurrencyFormatService sharedService];
    NSString *oneBTCRate = [fiatFormatter stringWithUnitForValue:self.transaction.fiatRate
                                                      inCurrency:self.transaction.fiatCurrency];

    return [NSString stringWithFormat:@"1 BTC = %@", oneBTCRate];
}

- (IBAction)showOnBlockchainInfoClicked:(id)sender {
    NSString *url = [NSString stringWithFormat:@"https://blockchain.info/tx/%@", self.transaction.id];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];

    [sender setState:NSOnState];
}

- (void)popoverDidClose:(NSNotification *)notification {
    id<HITransactionPopoverDelegate> delegate = self.delegate;

    if (delegate && [delegate respondsToSelector:@selector(transactionPopoverDidClose:)]) {
        [delegate transactionPopoverDidClose:self];
    }
}

@end
