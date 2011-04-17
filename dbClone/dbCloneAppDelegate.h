//
//  dbCloneAppDelegate.h
//  dbClone
//
//  Created by hrbrmstr on 4/16/11.
//  Copyright 2011 Bob Rudis. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface dbCloneAppDelegate : NSObject <NSApplicationDelegate> {
@private
    
    NSWindow *window;
    NSTextField *mothershipURL;
    NSTextField *dbEmail;
    NSTextField *dbHost;
    NSButton *captureButton;
    NSButton *saveToFile;
    NSTextView *logView;
    NSScrollView *scrollView ;
    
    NSString *logFilename ;
    NSString *hostId ;
    NSString *email ;
    
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextField *dbEmail;
@property (assign) IBOutlet NSTextView *logView;
@property (assign) IBOutlet NSScrollView *scrollView;
@property (assign) IBOutlet NSTextField *dbHost;
@property (assign) IBOutlet NSButton *captureButton;
@property (assign) IBOutlet NSButton *saveToFile; 

@property (nonatomic, retain) IBOutlet NSTextField *mothershipURL;

- (IBAction)captureDB:(id)sender;
- (IBAction)backupDB:(id)sender;
- (IBAction)restoreDB:(id)sender;

@end
