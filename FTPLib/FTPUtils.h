//
//  FTPUtils.h
//
//  Created by Tyler McAtee on 6/13/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h> 

@interface FTPUtils : NSObject
+ (NSURL *)smartURLForString:(NSString *)str;
+ (NSString *)pathForTemporaryFileWithPrefix:(NSString *)prefix;
+ (void)logStatus:(NSString *)statusString;
@end
