//
//  MusicFile.m
//  Elvira
//
//  Created by vas3k on 27.01.13.
//
//

#import "MusicFile.h"

@implementation MusicFile

@synthesize filename;
@synthesize cwd;

- (id)initWithFilename:(NSString*)_filename locatedIn:(NSString*)_cwd
{
    filename = [_filename copy];
    cwd = [_cwd copy];
    
    return self;
}

- (bool)isEqualTo:(MusicFile*)other
{
    return [self.filename isEqualToString:other.filename] && [self.cwd isEqualToArray:other.cwd];
}

- (id)copyWithZone:(NSZone*)zone
{
    return [[[self class] alloc] initWithFilename:filename locatedIn:cwd];
}

@end
