//
//  MusicManager.h
//  Elvira
//
//  Created by themylogin on 01.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#include <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>

#import "MusicFile.h"

typedef enum {
    NotBuffered,
    Buffering,
    Buffered,
    Playing
} MusicStateId;

typedef union {
    MusicStateId state;
    struct {
        MusicStateId state;
        float progress;
    } buffering;
} MusicState;

@interface MusicManager : NSObject

@property (nonatomic, retain) NSMutableArray* playlist;

@property (nonatomic) int nowPlayingTotal;
@property (nonatomic) int nowPlayingElapsed;

- (id)init;

- (void)bufferFile:(MusicFile*)file;

- (MusicState)getStateOfFile:(MusicFile*)file;
- (BOOL)willBufferAnythingInDirectory:(NSString*)directory locatedIn:(NSMutableArray*)cwd;

- (BOOL)playFile:(MusicFile*)file;
- (BOOL)seekTo:(float)seconds;
- (void)togglePause;

@end
