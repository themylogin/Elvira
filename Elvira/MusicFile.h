//
//  MusicFile.h
//  Elvira
//
//  Created by vas3k on 27.01.13.
//
//

#import <Foundation/Foundation.h>

@interface MusicFile : NSObject

@property(nonatomic, retain, readonly) NSString* filename;
@property(nonatomic, retain, readonly) NSMutableArray* cwd;

- (id)initWithFilename:(NSString*)filename locatedIn:(NSMutableArray*)cwd;
- (bool)isEqualTo:(MusicFile*)other;

@end
