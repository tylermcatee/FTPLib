//
//  FTPPut.h
//
//  Created by Tyler McAtee on 6/15/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTPObject.h"

@interface FTPPut : FTPObject <NSStreamDelegate>

-(BOOL)startUploadingFile:(NSString *)filePath;

@end
