//
//  pdf417Plugin.h
//  CDVpdf417
//
//  Created by Jurica Cerovec, Marko Mihovilic on 10/01/13.
//  Copyright (c) 2013 Racuni.hr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Cordova/CDV.h>

/**
 * pdf417 plugin class.
 * Responds to JS calls
 */
@interface CDVMicroblinkScanner : CDVPlugin

/**
 * Starts the scanning process
 */
- (void)scanWithCamera:(CDVInvokedUrlCommand *)command;

/**
 * Stop the scanning process and hide overlay
 */
- (void)hideCameraOverly:(CDVInvokedUrlCommand *)command;

/**
 * Process raw text data
 */
- (void)processRawText:(CDVInvokedUrlCommand *)command;

/**
 * Cancel Processing raw text data
 */
- (void)cancelRawTextProcessing:(CDVInvokedUrlCommand *)command;

/**
 * Returns successful recognition
 */
- (void)returnResults:(NSArray *)results cancelled:(BOOL)cancelled;

/**
 * Returns error, for example, not supported pdf417
 */
- (void)returnError:(NSString *)message;

@end
