//
//  FTPGet.m
//
//  Created by Tyler McAtee on 6/13/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import "FTPGet.h"
#include <CFNetwork/CFNetwork.h>

@interface FTPGet()
@property (nonatomic, assign, readonly ) BOOL              isReceiving;
@property (nonatomic, strong, readwrite) NSInputStream *   networkStream;
@property (nonatomic, copy,   readwrite) NSString *        filePath;
@property (nonatomic, strong, readwrite) NSOutputStream *  fileStream;
@end

@implementation FTPGet

#pragma mark - Core transfer code
// This is the code that actually does the networking.

- (BOOL)isReceiving
{
    return (self.networkStream != nil);
}

-(NSString *)startReceiveFile:(NSString *)fileName {
    // Starts a connection to download the fileName using the targetIP.
    BOOL success;
    NSURL *url;
    NSString *copyofFilePath;
    
    // These things should be closed from the last session.
    assert(self.networkStream == nil);
    assert(self.fileStream == nil);
    assert(self.filePath == nil);
    
    // First get and check the URL.
    url = [FTPUtils smartURLForString:[NSString stringWithFormat:@"%@%@", self.targetIP.targetIP, fileName]];
    success = (url != nil);
    
    [FTPUtils logStatus:[NSString stringWithFormat:@"Attempting to download from url %@", url]];
    
    // If the URL is bogus, let the user know.  Otherwise kick off the connection.
    if (!success) {
        
        [FTPUtils logStatus:[NSString stringWithFormat:@"The url %@ was invalid...", url]];
        
        return nil;
    } else {
        
        // Open a stream for the file we're going to receive into.
        self.filePath = [FTPUtils pathForTemporaryFileWithPrefix:@"Get"];
        assert(self.filePath != nil);
        copyofFilePath = [NSString stringWithString:self.filePath];
        
        [FTPUtils logStatus:[NSString stringWithFormat:@"Downloading file to path: %@", self.filePath]];
        
        self.fileStream = [NSOutputStream outputStreamToFileAtPath:self.filePath append:NO];
        assert(self.fileStream != nil);
        
        [self.fileStream open];
        
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
        
        [FTPUtils logStatus:@"Receiving file..."];
        
        while ([self isReceiving]) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
        
        return copyofFilePath;
    }

}

- (void)receiveDidStopWithStatus:(NSString *)statusString
{
    if (statusString == nil) {
        assert(self.filePath != nil);
        
        [FTPUtils logStatus:@"GET operation was successful!"];
        
        [FTPUtils logStatus:[NSString stringWithFormat:@"Downloaded file located at: %@", self.filePath]];
    }
    
    [FTPUtils logStatus:[NSString stringWithFormat:@"Receive stopped with status: %@", statusString]];
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
    if (self.fileStream != nil) {
        [self.fileStream close];
        self.fileStream = nil;
    }
    [self receiveDidStopWithStatus:statusString];
    self.filePath = nil;
    
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
// An NSStream delegate callback that's called when events happen on our
// network stream.
{
    #pragma unused(aStream)
    assert(aStream == self.networkStream);
    
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            
            [FTPUtils logStatus:@"Opened connection"];
            
        } break;
        case NSStreamEventHasBytesAvailable: {
            
            [FTPUtils logStatus:@"NSStreamEventHasBytesAvailable!"];
            
            NSInteger       bytesRead;
            uint8_t         buffer[32768];
            
            [FTPUtils logStatus:@"Receiving"];
            
            // Pull some data off the network.
            
            bytesRead = [self.networkStream read:buffer maxLength:sizeof(buffer)];
            if (bytesRead == -1) {
                
                [self stopReceiveWithStatus:@"Network read error"];
                
            } else if (bytesRead == 0) {
                [self stopReceiveWithStatus:nil];
            } else {
                NSInteger   bytesWritten;
                NSInteger   bytesWrittenSoFar;
                
                // Write to the file.
                bytesWrittenSoFar = 0;
                do {
                    bytesWritten = [self.fileStream write:&buffer[bytesWrittenSoFar] maxLength:(NSUInteger) (bytesRead - bytesWrittenSoFar)];
                    assert(bytesWritten != 0);
                    if (bytesWritten == -1) {
                        
                        [self stopReceiveWithStatus:@"File write error"];
                        
                        break;
                    } else {
                        bytesWrittenSoFar += bytesWritten;
                    }
                } while (bytesWrittenSoFar != bytesRead);
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

@end
