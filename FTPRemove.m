//
//  FTPRemove.m
//  removeTest
//
//  Created by Tyler McAtee on 6/15/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import "FTPRemove.h"

@interface FTPRemove()
@property Boolean test;
@property (nonatomic, strong) NSURL *url;
@property SInt32 status;
@property (nonatomic)  CFURLRef urlRef;
@end

@implementation FTPRemove

-(CFURLRef) urlRef {
    return (__bridge CFURLRef) self.url;
}

-(BOOL)removeFileAtPath:(NSString *)pathName {
    NSURL * url;
    SInt32 status = 0;
    url = [[NSURL alloc] initWithString:[self.targetIP formattedStringWithPathPostfix:pathName]];
    CFURLRef urlRef;
    urlRef = (__bridge CFURLRef) url;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // Ignoring warning for CFURLDestroyResource being deprecated, because
    // currently no better API exists for this functionality.
    [FTPUtils logStatus:[NSString stringWithFormat:@"Now removing file %@...", pathName]];
    Boolean test = CFURLDestroyResource(urlRef, &status);
#pragma clang diagnostic pop
    
    if(test){
        [FTPUtils logStatus:@"Remove was a success!"];
        return YES;
    } else {
        [FTPUtils logStatus:@"Remove failed."];
        return NO;
    }
}
@end
