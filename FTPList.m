//
//  FTPList.m
//  buildingFTPLibWithCommandLine
//
//  Created by Tyler McAtee on 6/15/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import "FTPList.h"
#include <CFNetwork/CFNetwork.h>
#include <sys/socket.h>
#include <sys/dirent.h>

@interface FTPList()
@property (nonatomic, strong, readwrite) NSMutableArray *  listEntries;
@property (nonatomic, assign, readonly ) BOOL              isReceiving;
@property (nonatomic, strong, readwrite) NSInputStream *   networkStream;
@property (nonatomic, strong, readwrite) NSMutableData *   listData;
@property (nonatomic, copy,   readwrite) NSString *        status;
@end

@implementation FTPList

#pragma mark * Status management

- (void)updateStatus:(NSString *)statusString
{
    assert(statusString != nil);
    self.status = statusString;
}

- (void)addListEntries:(NSArray *)newEntries
{
    if (self.listEntries == nil) {
        self.listEntries = [[NSMutableArray alloc] init];
    }
    
    [self.listEntries addObjectsFromArray:newEntries];
}

- (void)receiveDidStopWithStatus:(NSString *)statusString
{
    if (statusString == nil) {
        statusString = @"List succeeded";
    }
    [self updateStatus:statusString];
}

#pragma mark * Core transfer code

// This is the code that actually does the networking.

-(NSMutableArray *)receiveContentsOfPath:(NSString *)pathName {
    self.listEntries = [[NSMutableArray alloc] init];
    [self startReceiveForPath:pathName];
    return self.listEntries;
}

- (BOOL)isReceiving
{
    return (self.networkStream != nil);
}

- (void)startReceiveForPath:(NSString *)pathName
// Starts a connection to download the current URL.
{
    BOOL                success;
    NSURL *             url;
    
    assert(self.networkStream == nil);      // don't tap receive twice in a row!
    
    // First get and check the URL.
    
    url = [FTPUtils smartURLForString:[NSString stringWithFormat:@"%@%@", self.targetIP.targetIP, pathName]];
    success = (url != nil);
    
    // If the URL is bogus, let the user know.  Otherwise kick off the connection.
    
    if ( ! success) {
        [FTPUtils logStatus:@"Invalid url..."];
    } else {
        
        // Create the mutable data into which we will receive the listing.
        
        self.listData = [NSMutableData data];
        assert(self.listData != nil);
        
        // Open a CFFTPStream for the URL.
        
        self.networkStream = CFBridgingRelease(
                                               CFReadStreamCreateWithFTPURL(NULL, (__bridge CFURLRef) url)
                                               );
        assert(self.networkStream != nil);
        
        success = [self.networkStream setProperty:self.targetIP.userName forKey:(id)kCFStreamPropertyFTPUserName];
        assert(success);
        success = [self.networkStream setProperty:self.targetIP.password forKey:(id)kCFStreamPropertyFTPPassword];
        assert(success);
        
        self.networkStream.delegate = self;
        [self.networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.networkStream open];
        [FTPUtils logStatus:@"Receiving list..."];
        while ([self isReceiving]) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
    }
}

- (void)stopReceiveWithStatus:(NSString *)statusString
// Shuts down the connection and displays the result (statusString == nil)
// or the error status (otherwise).
{
    if (self.networkStream != nil) {
        [self.networkStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.networkStream.delegate = nil;
        [self.networkStream close];
        self.networkStream = nil;
    }
    [self receiveDidStopWithStatus:statusString];
    self.listData = nil;
}

- (NSDictionary *)entryByReencodingNameInEntry:(NSDictionary *)entry encoding:(NSStringEncoding)newEncoding
// CFFTPCreateParsedResourceListing always interprets the file name as MacRoman,
// which is clearly bogus <rdar://problem/7420589>.  This code attempts to fix
// that by converting the Unicode name back to MacRoman (to get the original bytes;
// this works because there's a lossless round trip between MacRoman and Unicode)
// and then reconverting those bytes to Unicode using the encoding provided.
{
    NSDictionary *  result;
    NSString *      name;
    NSData *        nameData;
    NSString *      newName;
    
    newName = nil;
    
    // Try to get the name, convert it back to MacRoman, and then reconvert it
    // with the preferred encoding.
    
    name = [entry objectForKey:(id) kCFFTPResourceName];
    if (name != nil) {
        assert([name isKindOfClass:[NSString class]]);
        
        nameData = [name dataUsingEncoding:NSMacOSRomanStringEncoding];
        if (nameData != nil) {
            newName = [[NSString alloc] initWithData:nameData encoding:newEncoding];
        }
    }
    
    // If the above failed, just return the entry unmodified.  If it succeeded,
    // make a copy of the entry and replace the name with the new name that we
    // calculated.
    
    if (newName == nil) {
        assert(NO);                 // in the debug builds, if this fails, we should investigate why
        result = (NSDictionary *) entry;
    } else {
        NSMutableDictionary *   newEntry;
        
        newEntry = [entry mutableCopy];
        assert(newEntry != nil);
        
        [newEntry setObject:newName forKey:(id) kCFFTPResourceName];
        
        result = newEntry;
    }
    
    return result;
}

- (void)parseListData
{
    NSMutableArray *    newEntries;
    NSUInteger          offset;
    
    // We accumulate the new entries into an array to avoid a) adding items to the
    // table one-by-one, and b) repeatedly shuffling the listData buffer around.
    
    newEntries = [NSMutableArray array];
    assert(newEntries != nil);
    
    offset = 0;
    do {
        CFIndex         bytesConsumed;
        CFDictionaryRef thisEntry;
        
        thisEntry = NULL;
        
        assert(offset <= [self.listData length]);
        bytesConsumed = CFFTPCreateParsedResourceListing(NULL, &((const uint8_t *) self.listData.bytes)[offset], (CFIndex) ([self.listData length] - offset), &thisEntry);
        if (bytesConsumed > 0) {
            
            // It is possible for CFFTPCreateParsedResourceListing to return a
            // positive number but not create a parse dictionary.  For example,
            // if the end of the listing text contains stuff that can't be parsed,
            // CFFTPCreateParsedResourceListing returns a positive number (to tell
            // the caller that it has consumed the data), but doesn't create a parse
            // dictionary (because it couldn't make sense of the data).  So, it's
            // important that we check for NULL.
            
            if (thisEntry != NULL) {
                NSDictionary *  entryToAdd;
                
                // Try to interpret the name as UTF-8, which makes things work properly
                // with many UNIX-like systems, including the Mac OS X built-in FTP
                // server.  If you have some idea what type of text your target system
                // is going to return, you could tweak this encoding.  For example,
                // if you know that the target system is running Windows, then
                // NSWindowsCP1252StringEncoding would be a good choice here.
                //
                // Alternatively you could let the user choose the encoding up
                // front, or reencode the listing after they've seen it and decided
                // it's wrong.
                //
                // Ain't FTP a wonderful protocol!
                
                entryToAdd = [self entryByReencodingNameInEntry:(__bridge NSDictionary *) thisEntry encoding:NSUTF8StringEncoding];
                
                [newEntries addObject:entryToAdd];
            }
            
            // We consume the bytes regardless of whether we get an entry.
            
            offset += (NSUInteger) bytesConsumed;
        }
        
        if (thisEntry != NULL) {
            CFRelease(thisEntry);
        }
        
        if (bytesConsumed == 0) {
            // We haven't yet got enough data to parse an entry.  Wait for more data
            // to arrive.
            break;
        } else if (bytesConsumed < 0) {
            // We totally failed to parse the listing.  Fail.
            [self stopReceiveWithStatus:@"Listing parse failed"];
            break;
        }
    } while (YES);
    
    if ([newEntries count] != 0) {
        [self addListEntries:newEntries];
    }
    if (offset != 0) {
        [self.listData replaceBytesInRange:NSMakeRange(0, offset) withBytes:NULL length:0];
    }
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
// An NSStream delegate callback that's called when events happen on our
// network stream.
{
#pragma unused(aStream)
    assert(aStream == self.networkStream);
    
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            [self updateStatus:@"Opened connection"];
        } break;
        case NSStreamEventHasBytesAvailable: {
            NSInteger       bytesRead;
            uint8_t         buffer[32768];
            
            [self updateStatus:@"Receiving"];
            
            // Pull some data off the network.
            
            bytesRead = [self.networkStream read:buffer maxLength:sizeof(buffer)];
            if (bytesRead < 0) {
                [self stopReceiveWithStatus:@"Network read error"];
            } else if (bytesRead == 0) {
                [self stopReceiveWithStatus:nil];
            } else {
                assert(self.listData != nil);
                
                // Append the data to our listing buffer.
                
                [self.listData appendBytes:buffer length:(NSUInteger) bytesRead];
                
                // Check the listing buffer for any complete entries and update
                // the UI if we find any.
                
                [self parseListData];
            }
        } break;
        case NSStreamEventHasSpaceAvailable: {
            assert(NO);     // should never happen for the output stream
        } break;
        case NSStreamEventErrorOccurred: {
            [self stopReceiveWithStatus:@"Stream open error"];
        } break;
        case NSStreamEventEndEncountered: {
            // ignore
        } break;
        default: {
            assert(NO);
        } break;
    }
}

#pragma mark * UI actions

- (NSString *)stringForNumber:(double)num asUnits:(NSString *)units
{
    NSString *  result;
    double      fractional;
    double      integral;
    
    fractional = modf(num, &integral);
    if ( (fractional < 0.1) || (fractional > 0.9) ) {
        result = [NSString stringWithFormat:@"%.0f %@", round(num), units];
    } else {
        result = [NSString stringWithFormat:@"%.1f %@", num, units];
    }
    return result;
}

- (NSString *)stringForFileSize:(unsigned long long)fileSizeExact
{
    double  fileSize;
    NSString *  result;
    
    fileSize = (double) fileSizeExact;
    if (fileSizeExact == 1) {
        result = @"1 byte";
    } else if (fileSizeExact < 1024) {
        result = [NSString stringWithFormat:@"%llu bytes", fileSizeExact];
    } else if (fileSize < (1024.0 * 1024.0 * 0.1)) {
        result = [self stringForNumber:fileSize / 1024.0 asUnits:@"KB"];
    } else if (fileSize < (1024.0 * 1024.0 * 1024.0 * 0.1)) {
        result = [self stringForNumber:fileSize / (1024.0 * 1024.0) asUnits:@"MB"];
    } else {
        result = [self stringForNumber:fileSize / (1024.0 * 1024.0 * 1024.0) asUnits:@"MB"];
    }
    return result;
}


@end
