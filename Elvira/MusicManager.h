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
} MusicState;

static const int kNumberBuffers = 1;
struct AQPlayerState {
    void*                         musicManager;
    
    AudioStreamBasicDescription   mDataFormat;
    AudioQueueRef                 mQueue;
    AudioQueueBufferRef           mBuffers[kNumberBuffers];
    AudioFileID                   mAudioFile;
    UInt32                        bufferByteSize;
    SInt64                        mCurrentPacket;
    UInt32                        mNumPacketsToRead;
    AudioStreamPacketDescription  *mPacketDescs;
    bool                          mIsRunning;
    UInt64                        mPacketCount;
};

@interface MusicManager : NSObject
{
    NSFileManager* fileManager;
    NSString* documentsDir;
    
    NSURLConnection*    nowBufferingConnection;
    NSMutableData*      nowBufferingData;
    uint                nowBufferingDataExpectedLength;
    MusicFile*          nowBufferingFile;
    
    MusicFile*          nowPlayingFile;
    
    bool paused;
    
    struct AQPlayerState aqData;
    
    bool shouldBufferNextFileOnEndBuffering;
    bool shouldPlayBufferedFileOnEndBuffering;
}

@property (nonatomic, retain) NSMutableArray* playlist;

@property (nonatomic) Float64 total;
@property (nonatomic) float elapsed;

- (id)init;
- (MusicState)getStateOfFile:(MusicFile*)file;
- (float)getFileBufferingProgress:(MusicFile*)file;

- (void)wantFile:(MusicFile*)file;
- (void)wantNextFile;

- (MusicFile*)nextFileFor:(MusicFile*)file;
- (NSString*)fsFilenameFor:(MusicFile*)file;
- (NSString*)libraryFilenameFor:(MusicFile*)file;

- (void)setPosition:(float)seconds;

@end
