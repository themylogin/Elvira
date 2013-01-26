//
//  MusicManager.h
//  Elvira
//
//  Created by themylogin on 01.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#include <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>

typedef enum {
    NotBuffered,
    Buffering,
    Buffered,
    Playing
} MusicState;

static const int kNumberBuffers = 3;
struct AQPlayerState {
    NSLock*                       lock;
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
};

@interface MusicManager : NSObject
{
    NSFileManager* fileManager;
    NSString* documentsDir;
    
    NSURLConnection* nowBufferingConnection;
    NSString* nowBufferingFilename;
    NSMutableData* nowBufferingData;
    uint nowBufferingDataExpectedLength;
    
    bool paused;
    bool nowPlayingFile;
        NSString* nowPlayingFileFilename;
        NSMutableArray* nowPlayingFileLocatedIn;
    bool nowPlayingBuffering;
    struct AQPlayerState aqData;
}

@property (nonatomic, retain) NSMutableArray* playlist;

- (id)init;
- (MusicState)getStateOfFile:(NSString*)filename locatedIn:(NSMutableArray*)cwd;
- (float)getFileBufferingProgress:(NSString*)filename locatedIn:(NSMutableArray*)cwd;

- (void)playFile:(NSString*)filename locatedIn:(NSMutableArray*)cwd;
- (void)playNextFile;

- (NSString*)fsFilenameFor:(NSString*)filename locatedIn:(NSMutableArray*)cwd;
- (NSString*)libraryFilenameFor:(NSString*)filename locatedIn:(NSMutableArray*)cwd;

@end
