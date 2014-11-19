//
//  FTPPut.m
//
//  Created by Tyler McAtee on 6/15/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import "FTPPut.h"
#include <CFNetwork/CFNetwork.h>

enum {
    kSendBufferSize = 32768
};

@interface FTPPut ()
@property (nonatomic, assign, readonly ) BOOL              isSending;
@property (nonatomic, strong, readwrite) NSOutputStream *  networkStream;
@property (nonatomic, strong, readwrite) NSInputStream *   fileStream;
@property (nonatomic, assign, readonly ) uint8_t *         buffer;
@property (nonatomic, assign, readwrite) size_t            bufferOffset;
@property (nonatomic, assign, readwrite) size_t            bufferLimit;
@property BOOL successfullySent;
@end

@implementation FTPPut
{
    uint8_t _buffer[kSendBufferSize];
}

#pragma mark - Initialization

+(instancetype)putterWithTargetIP:(FTPTargetIP *)targetIP {
    FTPPut *putter = [[FTPPut alloc] initWithTargetIP:targetIP];
    return putter;
}

#pragma mark - Core transfer code
// This is the code that actually does the networking.

// Because buffer is declared as an array, you have to use a custom getter.
// A synthesised getter doesn't compile.
- (uint8_t *)buffer
{
    return self->_buffer;
}

- (BOOL)isUploading
{
    return (self.networkStream != nil);
}

-(BOOL)startUploadingFile:(NSString *)filePath {
    BOOL                    success;
    NSURL *                 url;
    
    self.successfullySent = YES;
    
    assert(filePath != nil);
    assert([[NSFileManager defaultManager] fileExistsAtPath:filePath]);
    
    assert(self.networkStream == nil);      // don't tap send twice in a row!
    assert(self.fileStream == nil);         // ditto
    
    // First get and check the URL.
    
    url = [FTPUtils smartURLForString:self.targetIP.targetIP];
    success = (url != nil);
    
    [FTPUtils logStatus:[NSString stringWithFormat:@"Attempting to upload to url %@", url]];
    
    if (success) {
        // Add the last part of the file name to the end of the URL to form the final
        // URL that we're going to put to.
        url = CFBridgingRelease(
                                CFURLCreateCopyAppendingPathComponent(NULL, (__bridge CFURLRef) url, (__bridge CFStringRef) [filePath lastPathComponent], false)
                                );
        success = (url != nil);
    }
    
    // If the URL is bogus, let the user know.  Otherwise kick off the connection.
    if ( ! success) {
        [FTPUtils logStatus:[NSString stringWithFormat:@"The url %@ was invalid...", url]];
        return NO;
    } else {
        
        // Open a stream for the file we're going to send.  We do not open this stream;
        // NSURLConnection will do it for us.
        
        self.fileStream = [NSInputStream inputStreamWithFileAtPath:filePath];
        
        [FTPUtils logStatus:[NSString stringWithFormat:@"Uploading file to path: %@", filePath]];
        
        assert(self.fileStream != nil);
        
        [self.fileStream open];
        
        // Open a CFFTPStream for the URL.
        
        self.networkStream = CFBridgingRelease(
                                               CFWriteStreamCreateWithFTPURL(NULL, (__bridge CFURLRef) url)
                                               );
        assert(self.networkStream != nil);
        
        success = [self.networkStream setProperty:self.targetIP.userName forKey:(id)kCFStreamPropertyFTPUserName];
        assert(success);
        success = [self.networkStream setProperty:self.targetIP.password forKey:(id)kCFStreamPropertyFTPPassword];
        assert(success);
        
        self.networkStream.delegate = self;
        [self.networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.networkStream open];
        
        [FTPUtils logStatus:@"Uploading file..."];
        
        while ([self isUploading]) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
        return self.successfullySent;
    }
}

- (void)sendDidStopWithStatus:(NSString *)statusString
{
    if (statusString == nil) {
        statusString = @"PUT Operation was successful!";
    }
    [FTPUtils logStatus:[NSString stringWithFormat:@"Send stopped with status: %@", statusString]];
}



- (void)stopSendWithStatus:(NSString *)statusString
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
    [self sendDidStopWithStatus:statusString];
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
            assert(NO);     // should never happen for the output stream
        } break;
        case NSStreamEventHasSpaceAvailable: {
            
            [FTPUtils logStatus:@"Sending."];
            
            // If we don't have any data buffered, go read the next chunk of data.
            
            if (self.bufferOffset == self.bufferLimit) {
                NSInteger   bytesRead;
                
                bytesRead = [self.fileStream read:self.buffer maxLength:kSendBufferSize];
                
                if (bytesRead == -1) {
                    [self stopSendWithStatus:@"File read error"];
                } else if (bytesRead == 0) {
                    [self stopSendWithStatus:nil];
                } else {
                    self.bufferOffset = 0;
                    self.bufferLimit  = bytesRead;
                }
            }
            
            // If we're not out of data completely, send the next chunk.
            
            if (self.bufferOffset != self.bufferLimit) {
                NSInteger   bytesWritten;
                bytesWritten = [self.networkStream write:&self.buffer[self.bufferOffset] maxLength:self.bufferLimit - self.bufferOffset];
                assert(bytesWritten != 0);
                if (bytesWritten == -1) {
                    [self stopSendWithStatus:@"Network write error"];
                } else {
                    self.bufferOffset += bytesWritten;
                }
            }
        } break;
        case NSStreamEventErrorOccurred: {
            [self stopSendWithStatus:@"Stream open error"];
            self.successfullySent = NO;
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
