//
//  FTPObject.h
//
//  Created by Tyler McAtee on 6/13/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTPTargetIP.h"
#import "FTPUtils.h"

@interface FTPObject : NSObject
- (id)initWithTargetIP:(FTPTargetIP *)targetIP;
@property (strong, nonatomic) FTPTargetIP *targetIP;
@end
