//
//  pdf417Plugin.m
//  CDVpdf417
//
//  Created by Jurica Cerovec, Marko Mihovilic on 10/01/13.
//  Copyright (c) 2013 Racuni.hr. All rights reserved.
//

/**
 * Copyright (c)2013 Racuni.hr d.o.o. All rights reserved.
 *
 * ANY UNAUTHORIZED USE OR SALE, DUPLICATION, OR DISTRIBUTION
 * OF THIS PROGRAM OR ANY OF ITS PARTS, IN SOURCE OR BINARY FORMS,
 * WITH OR WITHOUT MODIFICATION, WITH THE PURPOSE OF ACQUIRING
 * UNLAWFUL MATERIAL OR ANY OTHER BENEFIT IS PROHIBITED!
 * THIS PROGRAM IS PROTECTED BY COPYRIGHT LAWS AND YOU MAY NOT
 * REVERSE ENGINEER, DECOMPILE, OR DISASSEMBLE IT.
 */

#import "CDVMicroblinkScanner.h"

#import "MBOverlayViewControllerDelegate.h"
#import "MBRecognizerSerializers.h"
#import "MBOverlaySettingsSerializers.h"
#import "MBRecognizerWrapper.h"

#import <MicroBlink/MicroBlink.h>

const NSString *RESULT_LIST = @"resultList";

const NSString *CANCELLED = @"cancelled";

const int COMPRESSED_IMAGE_QUALITY = 90;


@interface CDVPlugin () <MBOverlayViewControllerDelegate, MBStringProcessingRecognizerRunnerDelegate>

@property (nonatomic, retain) CDVInvokedUrlCommand *lastCommand;

@end

@interface CDVMicroblinkScanner ()

@property (nonatomic, strong) MBRecognizerCollection *recognizerCollection;
@property (nonatomic, strong) MBRecognizerCollection *recognizerCollectionDirectApi;
@property (nonatomic) id<MBRecognizerRunnerViewController> scanningViewController;

@property (nonatomic, strong) MBPdf417Recognizer *pdf417Recognizer;
@property (nonatomic, strong) MBRecognizerRunner *recognizerRunner;

@end

@implementation CDVMicroblinkScanner

@synthesize lastCommand;

/**
 Method  sanitizes the dictionary replaces all occurances of NSNull with nil

 @param dictionary JSON objects
 @return new dictionary with NSNull values replaced with nil
*/
- (NSDictionary *)sanitizeDictionary:(NSDictionary *)dictionary {
    NSMutableDictionary *mutableDictionary = [[NSMutableDictionary alloc] initWithDictionary:dictionary];
    for (NSString* key in dictionary.allKeys) {
        if (mutableDictionary[key] == [NSNull null]) {
            mutableDictionary[key] = nil;
        }
    }
    return mutableDictionary;
}

#pragma mark - Main
- (void)processRawText:(CDVInvokedUrlCommand *)command {
    [self setLastCommand:command];

    NSDictionary *jsonOverlaySettings = [self sanitizeDictionary:[self.lastCommand argumentAtIndex:0]];
    NSDictionary *jsonRecognizerCollection = [self sanitizeDictionary:[self.lastCommand argumentAtIndex:1]];
    NSDictionary *jsonLicenses = [self sanitizeDictionary:[self.lastCommand argumentAtIndex:2]];

    [self setLicense:jsonLicenses];

    self.recognizerCollectionDirectApi = [[MBRecognizerSerializers sharedInstance] deserializeRecognizerCollection:jsonRecognizerCollection];

    self.recognizerRunner = [[MBRecognizerRunner alloc] initWithRecognizerCollection:self.recognizerCollectionDirectApi];
    self.recognizerRunner.stringProcessingRecognizerRunnerDelegate = self;
    
    [self.recognizerRunner processString:[self.lastCommand argumentAtIndex:3]];
}

- (void)cancelRawTextProcessing:(CDVInvokedUrlCommand *)command {
    [self.recognizerRunner cancelProcessing];
}

- (void)hideCameraOverly:(CDVInvokedUrlCommand *)command {
    [[self viewController] dismissViewControllerAnimated:YES completion:nil];
    self.recognizerCollection = nil;
    self.scanningViewController = nil;

    NSDictionary *resultDict = @{
        CANCELLED : [NSNumber numberWithBool:YES]
    };

    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resultDict];
    [self.commandDelegate sendPluginResult:result callbackId:self.lastCommand.callbackId];
}

- (void)scanWithCamera:(CDVInvokedUrlCommand *)command {

    [self setLastCommand:command];

    NSDictionary *jsonOverlaySettings = [self sanitizeDictionary:[self.lastCommand argumentAtIndex:0]];
    NSDictionary *jsonRecognizerCollection = [self sanitizeDictionary:[self.lastCommand argumentAtIndex:1]];
    NSDictionary *jsonLicenses = [self sanitizeDictionary:[self.lastCommand argumentAtIndex:2]];

    [self setLicense:jsonLicenses];

    self.recognizerCollection = [[MBRecognizerSerializers sharedInstance] deserializeRecognizerCollection:jsonRecognizerCollection];

    // create overlay VC
    MBOverlayViewController *overlayVC = [[MBOverlaySettingsSerializers sharedInstance] createOverlayViewController:jsonOverlaySettings recognizerCollection:self.recognizerCollection delegate:self];

    UIViewController<MBRecognizerRunnerViewController>* recognizerRunnerViewController = [MBViewControllerFactory recognizerRunnerViewControllerWithOverlayViewController:overlayVC];

    self.scanningViewController = recognizerRunnerViewController;

    /** You can use other presentation methods as well */
    [[self viewController] presentViewController:recognizerRunnerViewController animated:YES completion:nil];
}

- (void)setLicense:(NSDictionary*) jsonLicense {
    if ([jsonLicense objectForKey:@"showTimeLimitedLicenseKeyWarning"] != nil) {
        BOOL showTimeLimitedLicenseKeyWarning = [[jsonLicense objectForKey:@"showTimeLimitedLicenseKeyWarning"] boolValue];
        [MBMicroblinkSDK sharedInstance].showLicenseKeyTimeLimitedWarning = showTimeLimitedLicenseKeyWarning;
    }
    NSString* iosLicense = [jsonLicense objectForKey:@"ios"];
    if ([jsonLicense objectForKey:@"licensee"] != nil) {
        NSString *licensee = [jsonLicense objectForKey:@"licensee"];
        [[MBMicroblinkSDK sharedInstance] setLicenseKey:iosLicense andLicensee:licensee];
    }
    else {
        [[MBMicroblinkSDK sharedInstance] setLicenseKey:iosLicense];
    }
}

#pragma mark - MBOverlayViewControllerDelegate
- (void)overlayViewControllerDidFinishScanning:(MBOverlayViewController *)overlayViewController state:(MBRecognizerResultState)state {
    if (state != MBRecognizerResultStateEmpty) {
        [overlayViewController.recognizerRunnerViewController pauseScanning];
        // recognizers within self.recognizerCollection now have their results filled
        NSMutableArray *jsonResults = [[NSMutableArray alloc] initWithCapacity:self.recognizerCollection.recognizerList.count];
        for (NSUInteger i = 0; i < self.recognizerCollection.recognizerList.count; ++i) {
            [jsonResults addObject:[[self.recognizerCollection.recognizerList objectAtIndex:i] serializeResult]];
        }

        NSDictionary *resultDict = @{
            CANCELLED: [NSNumber numberWithBool:NO],
            RESULT_LIST: jsonResults
        };

        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resultDict];
        [self.commandDelegate sendPluginResult:result callbackId:self.lastCommand.callbackId];

        // dismiss recognizer runner view controller
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self viewController] dismissViewControllerAnimated:YES completion:nil];
            self.recognizerCollection = nil;
            self.scanningViewController = nil;
        });
    }
}

- (void)overlayDidTapClose:(MBOverlayViewController *)overlayViewController {
    [[self viewController] dismissViewControllerAnimated:YES completion:nil];
    self.recognizerCollection = nil;
    self.scanningViewController = nil;
    NSDictionary *resultDict = @{
        CANCELLED : [NSNumber numberWithBool:YES]
    };
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resultDict];
    [self.commandDelegate sendPluginResult:result callbackId:self.lastCommand.callbackId];
}

#pragma mark - MBOverlayViewControllerDelegate
- (void)recognizerRunner:(nonnull MBRecognizerRunner *)recognizerRunner didFinishProcessingString:(nonnull NSString *)string {
    dispatch_async(dispatch_get_main_queue(), ^{

        NSMutableArray *jsonResults = [[NSMutableArray alloc] initWithCapacity:self.recognizerCollection.recognizerList.count];
        for (NSUInteger i = 0; i < self.recognizerCollectionDirectApi.recognizerList.count; ++i) {
            [jsonResults addObject:[[self.recognizerCollectionDirectApi.recognizerList objectAtIndex:i] serializeResult]];
        }

        NSDictionary *resultDict = @{
            CANCELLED: [NSNumber numberWithBool:NO],
            RESULT_LIST: jsonResults
        };

        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resultDict];
        [self.commandDelegate sendPluginResult:result callbackId:self.lastCommand.callbackId];

        self.recognizerCollectionDirectApi = nil;
        self.recognizerRunner = nil;
    });
}
@end
