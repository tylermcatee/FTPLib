//
//  FTPRemove.h
//  removeTest
//
//  Created by Tyler McAtee on 6/15/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import "FTPObject.h"

@interface FTPRemove : FTPObject

+(instancetype)removerWithTargetIP:(FTPTargetIP *)targetIP;

-(BOOL)removeFileAtPath:(NSString *)pathName;

@end
