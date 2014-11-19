//
//  FTPList.h
//  buildingFTPLibWithCommandLine
//
//  Created by Tyler McAtee on 6/15/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTPObject.h"

@interface FTPList : FTPObject <NSStreamDelegate>

-(NSMutableArray *)receiveContentsOfPath:(NSString *)pathName;

@end
