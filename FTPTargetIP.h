//
//  FTPTargetIP.h
//
//  Created by Tyler McAtee on 6/13/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FTPTargetIP : NSObject

@property (strong, nonatomic) NSString *targetIP;
@property (strong, nonatomic) NSString *userName;
@property (strong, nonatomic) NSString *password;

-(id)initWithIP:(NSString *)ipAddress andUsername:(NSString *)username andPassword:(NSString *)password;

-(NSString *)formattedStringWithPathPostfix:(NSString *)pathPostfix;

@end
