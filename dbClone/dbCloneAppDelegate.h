//
//  dbCloneAppDelegate.h
//  dbClone
//
//  Created by boB Rudis on 4/13/11.
//  Copyright 2011 Liberty Mutual. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface dbCloneAppDelegate : NSObject <NSApplicationDelegate> {
@private
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
