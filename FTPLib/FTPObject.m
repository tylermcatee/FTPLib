//
//  FTPObject.m
//
//  Created by Tyler McAtee on 6/13/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import "FTPObject.h"

@implementation FTPObject

#pragma mark - Target IP Handling code

-(FTPTargetIP *)targetIP {
    if (!_targetIP) _targetIP = [[FTPTargetIP alloc] init];
    return _targetIP;
}

-(id)initWithTargetIP:(FTPTargetIP *)targetIP {
    self = [super init];
    if (self) {
        self.targetIP = targetIP;
    }
    return self;
}

@end
