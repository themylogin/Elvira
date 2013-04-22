//
//  MusicManager.m
//  Elvira
//
//  Created by themylogin on 01.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MusicManager.h"

#import <AVFoundation/AVAudioSession.h>

static const int kNumberBuffers = 1;
typedef struct {
    void*                         musicManager;
    
    AudioQueueRef                 mQueue;
    AudioQueueBufferRef           mBuffers[kNumberBuffers];
    UInt32                        bufferByteSize;
    
    bool                          mPaused;    
    
    AudioFileID                   mAudioFile;
    AudioStreamBasicDescription   mDataFormat;
    UInt64                        mPacketCount;
    UInt32                        mNumPacketsToRead;
    SInt64                        mCurrentPacket;
    AudioStreamPacketDescription* mPacketDescs;
    
    Float64                       mDuration;
    Float64                       mElapsed;
} AQPlayerState;

@interface MusicManager ()

@property (nonatomic, retain) NSFileManager*    fileManager;
@property (nonatomic, retain) NSString*         documentsDir;

@property (nonatomic, retain) NSMutableArray*   bufferingQueue;

@property (nonatomic, retain) MusicFile*        nowBufferingFile;
@property (nonatomic, retain) NSURLConnection*  nowBufferingConnection;
@property (nonatomic)         uint              nowBufferingDataExpectedLength;
@property (nonatomic, retain) NSMutableData*    nowBufferingData;
@property (nonatomic)         bool              playNowBufferingFileWhenBufferedEnough;

@property (nonatomic, retain) MusicFile*        nowPlayingFile;

@property (nonatomic)         AQPlayerState     aqData;

@end

@implementation MusicManager

@synthesize fileManager;
@synthesize documentsDir;

@synthesize bufferingQueue;

@synthesize nowBufferingConnection;
@synthesize nowBufferingData;
@synthesize nowBufferingDataExpectedLength;
@synthesize nowBufferingFile;

@synthesize playlist;

@synthesize nowPlayingFile;
@synthesize nowPlayingTotal;
@synthesize nowPlayingElapsed;

@synthesize aqData;

- (id)init
{
    self.fileManager = [NSFileManager defaultManager];
    self.documentsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    self.bufferingQueue = [[NSMutableArray alloc] init];
    
    self.nowBufferingFile = nil;
    self.nowBufferingConnection = nil;
    self.nowBufferingDataExpectedLength = 0;
    self.nowBufferingData = 0;
    self.playNowBufferingFileWhenBufferedEnough = FALSE;
    
    self.nowPlayingFile = nil;
    self.nowPlayingTotal = 0;
    self.nowPlayingElapsed = 0;
    
    // audio queue
    aqData.musicManager = self;
    aqData.mQueue = NULL;
    
    AudioSessionInitialize(NULL, NULL, InterruptionListener, self);
    UInt32 category = kAudioSessionCategory_MediaPlayback;
    AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
    AudioSessionSetActive(true);
    
    return self;
}

#pragma mark - Buffering

- (void)bufferFile:(MusicFile*)file
{
    [self.bufferingQueue addObject:file];
    [self doBuffering];
}

- (void)doBuffering
{
    if (self.nowBufferingConnection)
    {
        return;
    }
    if (self.bufferingQueue.count == 0)
    {
        return;
    }
    
    self.nowBufferingFile = [[self.bufferingQueue objectAtIndex:0] copy];
    [self.bufferingQueue removeObjectAtIndex:0];
    
    if ([self.fileManager fileExistsAtPath:[self fsFilenameFor:self.nowBufferingFile]])
    {
        [self doBuffering];
        return;
    }
    
    self.nowBufferingDataExpectedLength = 0;
    self.nowBufferingConnection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[@"http://player.thelogin.ru/index/get_file?file=" stringByAppendingString:[[self libraryFilenameFor:self.nowBufferingFile] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0] delegate:self];
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError *)error
{
    self.nowBufferingFile = nil;
    self.nowBufferingConnection = nil;
    self.nowBufferingDataExpectedLength = 0;
    self.nowBufferingData = nil;
    
    [self doBuffering];
}

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse *)response
{
    if ([(NSHTTPURLResponse*)response statusCode] != 200)
    {
        self.nowBufferingFile = nil;
        self.nowBufferingConnection = nil;
        self.nowBufferingDataExpectedLength = 0;
        self.nowBufferingData = nil;
        
        [self doBuffering];
    }
    
    self.nowBufferingDataExpectedLength = response.expectedContentLength;
    self.nowBufferingData = [[NSMutableData alloc] initWithCapacity:nowBufferingDataExpectedLength];
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData *)data
{
    [self.nowBufferingData appendData:data];
    [self change];
    
    if (self.playNowBufferingFileWhenBufferedEnough && [self.nowBufferingData length] >= self.nowBufferingDataExpectedLength * 0.3)
    {
        [self playFile:self.nowBufferingFile];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection*)connection
{
    [self.nowBufferingData writeToFile:[self fsFilenameFor:self.nowBufferingFile] atomically:YES];
    
    if (self.nowPlayingFile && [self.nowPlayingFile isEqualTo:self.nowBufferingFile])
    {
        AudioFileClose(aqData.mAudioFile);
        aqData.mAudioFile = [self openAudioFile:self.nowPlayingFile];
    }
    
    self.nowBufferingFile = nil;
    self.nowBufferingConnection = nil;
    self.nowBufferingDataExpectedLength = 0;
    self.nowBufferingData = nil;    
    
    [self change];
    
    [self doBuffering];
}

# pragma mark - State retrieving

- (MusicState)getStateOfFile:(MusicFile*)file
{
    MusicState state;
    if ([self.fileManager fileExistsAtPath:[self fsFilenameFor:file]])
    {
        if ([file isEqualTo:self.nowPlayingFile])
        {
            state.state = BufferedPlaying;
            return state;
        }
        else 
        {
            state.state = Buffered;
            return state;
        }
    }
    else
    {
        if ([file isEqualTo:self.nowBufferingFile])
        {
            state.buffering.progress = nowBufferingDataExpectedLength > 0 ? (float)nowBufferingData.length / (float)nowBufferingDataExpectedLength : 0.0;
            if ([file isEqualTo:self.nowPlayingFile])
            {
                state.state = BufferingPlaying;
            }
            else
            {
                state.state = Buffering;
            }
            return state;
        }
        
        for (MusicFile* anotherFile in self.bufferingQueue)
        {
            if ([anotherFile isEqualTo:file])
            {
                state.state = Buffering;
                state.buffering.progress = 0.0;
                return state;
            }
        }
        
        state.state = NotBuffered;
        return state;
    }
}

- (BOOL)willBufferAnythingInDirectory:(NSString*)directory locatedIn:(NSMutableArray*)cwd;
{
    NSString* prefix = [self libraryFilenameFor:[[MusicFile alloc] initWithFilename:directory locatedIn:cwd]];
    for (MusicFile* file in self.bufferingQueue)
    {
        if ([[self libraryFilenameFor:file] hasPrefix:prefix])
        {
            return TRUE;
        }
    }
    return FALSE;
}

# pragma mark - Play control

-(BOOL)playFile:(MusicFile*)file
{
    self.playNowBufferingFileWhenBufferedEnough = FALSE;
    
    if (aqData.mQueue)
    {
        AudioQueueStop(aqData.mQueue, true);
        AudioQueueDispose(aqData.mQueue, true);
        AudioFileClose(aqData.mAudioFile);
        free(aqData.mPacketDescs);
        
        aqData.mQueue = NULL;
    }
    
    AudioFileID audioFile = [self openAudioFile:file];
    if (!audioFile)
    {
        if (!self.nowBufferingFile)
        {
            [self bufferFile:file];
        }
        
        if ([file isEqualTo:self.nowBufferingFile])
        {
            if (self.nowBufferingData && self.nowBufferingDataExpectedLength && [self.nowBufferingData length] >= self.nowBufferingDataExpectedLength * 0.3)
            {
                if (AudioFileOpenWithCallbacks(self, NowBuffering_AudioFile_ReadProc, NULL, NowBuffering_AudioFile_GetSizeProc, NULL, kAudioFileMP3Type, &audioFile))
                {
                    return FALSE;
                }
            }
            else
            {
                self.playNowBufferingFileWhenBufferedEnough = TRUE;
                return TRUE;
            }
        }
        else
        {
            return FALSE;
        }
    }
    
    [self enqueueAudioFile:audioFile deriveBufferSize:TRUE];
    
    AudioQueueNewOutput(&aqData.mDataFormat, HandleOutputBuffer, &aqData, NULL, NULL, 0, &aqData.mQueue);
    for (int i = 0; i < kNumberBuffers; ++i)
    {
        AudioQueueAllocateBuffer(aqData.mQueue, aqData.bufferByteSize, &aqData.mBuffers[i]);
        HandleOutputBuffer(&aqData, aqData.mQueue, aqData.mBuffers[i]);
    }
    
    aqData.mPaused = FALSE;
    AudioQueueStart(aqData.mQueue, NULL);
    
    self.nowPlayingFile = file;
    self.nowPlayingTotal = aqData.mDuration;
    [self change];
    return TRUE;
}

- (BOOL)seekTo:(float)seconds
{
    SInt64 newCurrentPacket = self.aqData.mPacketCount * (seconds / self.aqData.mDuration);
    if (newCurrentPacket < self.aqData.mPacketCount)
    {
        aqData.mCurrentPacket = newCurrentPacket;
        return TRUE;
    }
    else
    {
        return FALSE;
    }
}

- (void)togglePause
{
    if (aqData.mPaused)
    {
        AudioQueueStart(aqData.mQueue, NULL);
        aqData.mPaused = FALSE;
    }
    else
    {
        AudioQueuePause(aqData.mQueue);
        aqData.mPaused = TRUE;
    }
}

#pragma mark - Internals

- (void)change
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"change" object:self];
}

- (NSString*)fsFilenameFor:(MusicFile*)file
{
    return [[[documentsDir stringByAppendingString:@"/"] stringByAppendingString:[[[file.cwd componentsJoinedByString:@"@"] stringByAppendingString:@"@"] stringByAppendingString:file.filename]] stringByAppendingString:@".mp3"];
}

- (NSString*)libraryFilenameFor:(MusicFile*)file
{
    return [[[file.cwd componentsJoinedByString:@"/"] stringByAppendingString:@"/"] stringByAppendingString:file.filename];
}

- (AudioFileID)openAudioFile:(MusicFile*)file
{
    NSString* fsFilename = [self fsFilenameFor:file];
    if (![self.fileManager fileExistsAtPath:[self fsFilenameFor:file]])
    {
        return NULL;
    }
    
    AudioFileID audioFile;
    CFURLRef audioFileURL = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8*)[fsFilename UTF8String], [fsFilename lengthOfBytesUsingEncoding:NSUTF8StringEncoding],false);
    AudioFileOpenURL(audioFileURL, 0x01, 0, &audioFile);
    CFRelease(audioFileURL);
    return audioFile;
}

- (void)enqueueAudioFile:(AudioFileID)audioFile deriveBufferSize:(BOOL)deriveBufferSize
{
    aqData.mAudioFile = audioFile;
    aqData.mCurrentPacket = 0;
    
    UInt32 propertySize;
    // get length
    propertySize = sizeof(aqData.mPacketCount);
    AudioFileGetProperty(audioFile, kAudioFilePropertyAudioDataPacketCount, &propertySize, &aqData.mPacketCount);
    // get duration
    propertySize = sizeof(aqData.mDuration);
    AudioFileGetProperty(audioFile, kAudioFilePropertyEstimatedDuration, &propertySize, &aqData.mDuration);
    // get data format
    propertySize = sizeof(aqData.mDataFormat);
    AudioFileGetProperty(audioFile, kAudioFilePropertyDataFormat, &propertySize, &aqData.mDataFormat);
    
    UInt32 maxPacketSize;
    propertySize = sizeof(maxPacketSize);
    AudioFileGetProperty(aqData.mAudioFile, kAudioFilePropertyPacketSizeUpperBound, &propertySize, &maxPacketSize);
    
    if (deriveBufferSize)
    {
        DeriveBufferSize(&aqData.mDataFormat, maxPacketSize, 0.5, &aqData.bufferByteSize, &aqData.mNumPacketsToRead);
    }
    
    // VBR
    if (aqData.mDataFormat.mBytesPerPacket == 0 || aqData.mDataFormat.mFramesPerPacket == 0)
    {
        aqData.mPacketDescs = (AudioStreamPacketDescription*)malloc(aqData.mNumPacketsToRead * sizeof(AudioStreamPacketDescription));
    }
    else
    {
        aqData.mPacketDescs = NULL;
    }
    
    UInt32 cookieSize = sizeof(UInt32);
    if (!AudioFileGetPropertyInfo(aqData.mAudioFile, kAudioFilePropertyMagicCookieData, &cookieSize, NULL) && cookieSize)
    {
        char* magicCookie = (char*)malloc(cookieSize);
        AudioFileGetProperty(aqData.mAudioFile, kAudioFilePropertyMagicCookieData, &cookieSize, magicCookie);
        AudioQueueSetProperty(aqData.mQueue, kAudioQueueProperty_MagicCookie, magicCookie, cookieSize);
        free(magicCookie);
    }
}

#pragma mark - Audio Session

void InterruptionListener(void* inClientData, UInt32 inInterruptionState)
{
    MusicManager* mm = (MusicManager*)inClientData;
    if (inInterruptionState == kAudioSessionBeginInterruption)
    {
        AudioSessionSetActive(false);
    }
    if (inInterruptionState == kAudioSessionEndInterruption)
    {
        UInt32 category = kAudioSessionCategory_MediaPlayback;
        AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
        AudioSessionSetActive(true);
        
        AudioQueueStart(mm->aqData.mQueue, NULL);
    }
}

void HandleOutputBuffer(void *aqData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer)
{
    AQPlayerState* pAqData = (AQPlayerState*)aqData;
    MusicManager* pMusicManager = (MusicManager*)pAqData->musicManager;
    
    Float64 elapsed = pAqData->mDuration * pAqData->mCurrentPacket / pAqData->mPacketCount;
    if ((int)elapsed != pMusicManager.nowPlayingElapsed)
    {
        pMusicManager.nowPlayingElapsed = (int)elapsed;
        [pMusicManager change];
    }
    
    UInt32 numBytesReadFromFile;
    UInt32 numPackets = pAqData->mNumPacketsToRead;
    AudioFileReadPackets(pAqData->mAudioFile, false, &numBytesReadFromFile, pAqData->mPacketDescs, pAqData->mCurrentPacket, &numPackets, inBuffer->mAudioData);
    if (numPackets > 0)
    {
        inBuffer->mAudioDataByteSize = numBytesReadFromFile;
        AudioQueueEnqueueBuffer(pAqData->mQueue, inBuffer, (pAqData->mPacketDescs ? numPackets : 0), pAqData->mPacketDescs);
        pAqData->mCurrentPacket += numPackets;
    }
    else
    {        
        if (pMusicManager.playlist.count == 0)
        {
            AudioQueueStop(pAqData->mQueue, true);
            AudioQueueDispose(pAqData->mQueue, true);
            AudioFileClose(pAqData->mAudioFile);
            free(pAqData->mPacketDescs);
            
            pAqData->mQueue = NULL;
            
            pMusicManager.nowPlayingFile = NULL;
            pMusicManager.nowPlayingTotal = 0;
            pMusicManager.nowPlayingElapsed = 0;
            
            [pMusicManager change];
        }
        else
        {
            MusicFile* file = [pMusicManager.playlist objectAtIndex:0];
            [pMusicManager.playlist removeObjectAtIndex:0];
            
            AudioFileID audioFile = [pMusicManager openAudioFile:file];
            
            AudioStreamBasicDescription dataFormat;
            UInt32 propertySize = sizeof(dataFormat);
            AudioFileGetProperty(audioFile, kAudioFilePropertyDataFormat, &propertySize, &dataFormat);
            if (memcmp(&pAqData->mDataFormat, &dataFormat, propertySize) == 0)
            {
                if (pAqData->mPacketDescs)
                {
                    free(pAqData->mPacketDescs);
                }
                
                [pMusicManager enqueueAudioFile:audioFile deriveBufferSize:FALSE];
                                
                pMusicManager.nowPlayingFile = file;
                pMusicManager.nowPlayingTotal = pAqData->mDuration;
                [pMusicManager change];
                
                HandleOutputBuffer(aqData, inAQ, inBuffer);
            }
            else
            {
                [pMusicManager playFile:file];                
            }            
        }
    }
}

void DeriveBufferSize(
                      AudioStreamBasicDescription *ASBDesc,                            // 1
                      UInt32                      maxPacketSize,                       // 2
                      Float64                     seconds,                             // 3
                      UInt32                      *outBufferSize,                      // 4
                      UInt32                      *outNumPacketsToRead                 // 5
                      )
{
    static const int maxBufferSize = 0x50000;                        // 6
    static const int minBufferSize = 0x4000;                         // 7
    
    if (ASBDesc->mFramesPerPacket != 0) {                             // 8
        Float64 numPacketsForTime =
        ASBDesc->mSampleRate / ASBDesc->mFramesPerPacket * seconds;
        *outBufferSize = numPacketsForTime * maxPacketSize;
    } else {                                                         // 9
        *outBufferSize =
        maxBufferSize > maxPacketSize ?
        maxBufferSize : maxPacketSize;
    }
    
    if (                                                             // 10
        *outBufferSize > maxBufferSize &&
        *outBufferSize > maxPacketSize
        )
        *outBufferSize = maxBufferSize;
    else {                                                           // 11
        if (*outBufferSize < minBufferSize)
            *outBufferSize = minBufferSize;
    }
    
    *outNumPacketsToRead = *outBufferSize / maxPacketSize;           // 12
}

#pragma mark - AudioFileOpenWithCallbacks

OSStatus NowBuffering_AudioFile_ReadProc(void* inClientData, SInt64 inPosition, UInt32 requestCount, void* buffer, UInt32* actualCount)
{
    MusicManager* musicManager = (MusicManager*)inClientData;
    if (musicManager->nowBufferingData)
    {
        if (inPosition < [musicManager->nowBufferingData length])
        {
            *actualCount = requestCount;
            if (inPosition + *actualCount > [musicManager->nowBufferingData length])
            {
                *actualCount = [musicManager->nowBufferingData length] - inPosition;
            }
            
            memcpy(buffer, [musicManager->nowBufferingData bytes] + inPosition, *actualCount);
            return noErr;
        }
    }
    
    *actualCount = 0;
    return noErr;
}

SInt64 NowBuffering_AudioFile_GetSizeProc(void* inClientData)
{
    MusicManager* musicManager = (MusicManager*)inClientData;
    if (musicManager->nowBufferingDataExpectedLength)
    {
        return musicManager->nowBufferingDataExpectedLength;
    }
    
    
    return EINVAL;
}

@end
