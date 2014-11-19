//
//  FTPTargetIP.m
//
//  Created by Tyler McAtee on 6/13/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import "FTPTargetIP.h"

@implementation FTPTargetIP

#define DEFAULT_IP ""
#define DEFAULT_USERNAME ""
#define DEFAULT_PASSWORD ""

-(NSString *)targetIP {
    if (!_targetIP) _targetIP = @DEFAULT_IP;
    return _targetIP;
}
-(NSString *)userName {
    if (!_userName) _userName = @DEFAULT_USERNAME;
    return _userName;
}
-(NSString *)password {
    if (!_password) _password = @DEFAULT_PASSWORD;
    return _password;
}

# pragma mark - Public Methods

+(instancetype)ipWithAddress:(NSString *)ipAddress andUserName:(NSString *)username andPassword:(NSString *)password {
    FTPTargetIP *targetIP = [[FTPTargetIP alloc] initWithIP:ipAddress andUsername:username andPassword:password];
    return targetIP;
}

-(id)initWithIP:(NSString *)ipAddress andUsername:(NSString *)username andPassword:(NSString *)password {
    self = [super init];
    if (self) {
        self.targetIP = ipAddress;
        self.userName = username;
        self.password = password;
    }
    return self;
}

-(NSString *)formattedStringWithPathPostfix:(NSString *)pathPostfix {
    NSString *basicTargetIP = [self.targetIP stringByReplacingOccurrencesOfString:@"ftp://" withString:@""];
    
    return [NSString stringWithFormat:@"ftp://%@:%@@%@%@", self.userName, self.password, basicTargetIP, pathPostfix];
}

@end
