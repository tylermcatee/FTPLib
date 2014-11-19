//
//  FTPRemove.h
//  removeTest
//
//  Created by Tyler McAtee on 6/15/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import "FTPObject.h"

@interface FTPRemove : FTPObject

-(BOOL)removeFileAtPath:(NSString *)pathName;

@end
