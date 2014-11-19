//
//  FTPGet.h
//
//  Created by Tyler McAtee on 6/13/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTPObject.h"

@interface FTPGet : FTPObject <NSStreamDelegate>

-(NSString *)startReceiveFile:(NSString *)fileName;

@end
