//
//  MusicManager.m
//  Elvira
//
//  Created by themylogin on 01.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MusicManager.h"

#import <AVFoundation/AVAudioSession.h>

@implementation MusicManager

@synthesize playlist;

- (id)init
{
    // files
    fileManager = [NSFileManager defaultManager];
    documentsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    [fileManager retain];
    [documentsDir retain];
    
    // audio queue
    aqData.lock = [[NSRecursiveLock alloc] init];
    aqData.musicManager = self;
    aqData.mQueue = NULL;
    
    AudioSessionInitialize(NULL, NULL, interruptionListener, self);
    UInt32 category = kAudioSessionCategory_MediaPlayback;
    AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
    AudioSessionSetActive(true);
    
    nowBufferingFile = nil;
    
    nowPlayingFile = nil;
    
    paused = false;
    
    shouldBufferNextFileOnEndBuffering = false;
    shouldPlayBufferedFileOnEndBuffering = false;
    
    return self;
}

- (MusicState)getStateOfFile:(MusicFile*)file
{
    if ([nowPlayingFile isEqualTo:file])
    {
        return Playing;
    }
    if ([fileManager fileExistsAtPath:[self fsFilenameFor:file]])
    {
        return Buffered;
    }
    if ([nowBufferingFile isEqualTo:file])
    {
        return Buffering;
    }    
    return NotBuffered;
}

- (float)getFileBufferingProgress:(MusicFile*)file
{
    if ([nowBufferingFile isEqualTo:file] && nowBufferingDataExpectedLength > 0)
    {
        return (float)nowBufferingData.length / (float)nowBufferingDataExpectedLength;
    }
    
    return 0.0;
}

- (void)wantFile:(MusicFile*)file
{    
    MusicState state = [self getStateOfFile:file];
    if (state == Buffered)
    {
        [self playFile:file];
    }
    if (state == Buffering)
    {
        // ...
    }
    if (state == NotBuffered)
    {
        shouldPlayBufferedFileOnEndBuffering = true;
        shouldBufferNextFileOnEndBuffering = true;
        
        [self bufferFile:file];
    }
}

- (void)wantNextFile
{
    MusicFile* nextFile = [self nextFileFor:nowPlayingFile];
    if (nextFile)
    {
        [self wantFile:nextFile];
    }
}

- (void)bufferFile:(MusicFile*)file
{
    [nowBufferingData release];
    [nowBufferingConnection cancel];
    
    nowBufferingFile = [file copy];
    nowBufferingDataExpectedLength = 0;
    nowBufferingConnection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[@"http://player.thelogin.ru/index/get_file?file=" stringByAppendingString:[[self libraryFilenameFor:file] stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]]] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0] delegate:self];
}

-(void)playFile:(MusicFile*)file
{    
    [aqData.lock lock];
    // open file
    NSString* fsFilename = [self fsFilenameFor:file];
    CFURLRef audioFileURL = CFURLCreateFromFileSystemRepresentation(NULL,
                                                                    (const UInt8*)[fsFilename UTF8String],
                                                                    [fsFilename lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                                                    false);
    AudioFileID audioFile;
    AudioFileOpenURL(audioFileURL, 0x01, 0, &audioFile);
    CFRelease(audioFileURL);
    // get data format
    AudioStreamBasicDescription dataFormat;
    UInt32 dataFormatSize = sizeof(aqData.mDataFormat);
    AudioFileGetProperty(audioFile, kAudioFilePropertyDataFormat, &dataFormatSize, &dataFormat);
    // if audio queue exists and formats are equal, we can just substitute mAudioFile with our file
    if (aqData.mQueue && memcmp(&aqData.mDataFormat, &dataFormat, dataFormatSize) == 0 && false)
    {
        aqData.mAudioFile = audioFile;
    }
    else
    {
        if (aqData.mQueue)
        {
            AudioQueueStop(aqData.mQueue, true);
            AudioQueueDispose(aqData.mQueue, true);
            AudioFileClose(aqData.mAudioFile);
            free(aqData.mPacketDescs);
        }
        
        aqData.mAudioFile = audioFile;
        aqData.mDataFormat = dataFormat;
        AudioQueueNewOutput(&aqData.mDataFormat, HandleOutputBuffer, &aqData, NULL, NULL, 0, &aqData.mQueue);
        
        UInt32 maxPacketSize;
        UInt32 propertySize = sizeof (maxPacketSize);
        AudioFileGetProperty(aqData.mAudioFile, kAudioFilePropertyPacketSizeUpperBound, &propertySize, &maxPacketSize);
        
        DeriveBufferSize(&aqData.mDataFormat, maxPacketSize, 0.5, &aqData.bufferByteSize, &aqData.mNumPacketsToRead);
        
        // VBR
        if (aqData.mDataFormat.mBytesPerPacket == 0 || aqData.mDataFormat.mFramesPerPacket == 0)
        {
            aqData.mPacketDescs = (AudioStreamPacketDescription*)malloc(aqData.mNumPacketsToRead * sizeof (AudioStreamPacketDescription));
        }
        else
        {
            aqData.mPacketDescs = NULL;
        }
        
        UInt32 cookieSize = sizeof(UInt32);
        if (!AudioFileGetPropertyInfo(aqData.mAudioFile, kAudioFilePropertyMagicCookieData, &cookieSize, NULL) && cookieSize)
        {
            char* magicCookie = (char *)malloc(cookieSize);
            AudioFileGetProperty(aqData.mAudioFile, kAudioFilePropertyMagicCookieData, &cookieSize, magicCookie);
            AudioQueueSetProperty(aqData.mQueue, kAudioQueueProperty_MagicCookie, magicCookie, cookieSize);
            free(magicCookie);
        }
        
        for (int i = 0; i < kNumberBuffers; ++i)
        {
            AudioQueueAllocateBuffer(aqData.mQueue, aqData.bufferByteSize, &aqData.mBuffers[i]);
            HandleOutputBuffer(&aqData, aqData.mQueue, aqData.mBuffers[i]);
        }
        
        Float32 gain = 1.0;
        AudioQueueSetParameter(aqData.mQueue, kAudioQueueParam_Volume, gain);
        
        AudioQueueStart(aqData.mQueue, NULL);
    }
    aqData.mCurrentPacket = 0;
    
    nowPlayingFile = [file copy];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"musicManagerStateChange" object:self];
    [aqData.lock unlock];
}

// NSURLConnection delegates

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError *)error
{
    // [data setLength:0];
}

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse *)response
{
    nowBufferingDataExpectedLength = response.expectedContentLength;
    nowBufferingData = [[NSMutableData alloc] initWithCapacity:nowBufferingDataExpectedLength];
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData *)data
{
    [nowBufferingData appendData:data];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"musicManagerStateChange" object:self];
}

- (void)connectionDidFinishLoading:(NSURLConnection*)connection
{
    [nowBufferingData writeToFile:[self fsFilenameFor:nowBufferingFile] atomically:YES];
    
    if (shouldPlayBufferedFileOnEndBuffering)
    {
        [self playFile:nowBufferingFile];
        shouldPlayBufferedFileOnEndBuffering = false;
    }
    
    if (shouldBufferNextFileOnEndBuffering)
    {
        MusicFile* nextFile = nowBufferingFile;
        while ((nextFile = [self nextFileFor:nextFile]))
        {
            if ([self getStateOfFile:nextFile] == NotBuffered)
            {
                [self bufferFile:[self nextFileFor:nowBufferingFile]];
                break;
            }
        }
    }
}

// Audio Session
void interruptionListener(	void *	inClientData,
                          UInt32	inInterruptionState)
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

// Audio Queue
static void HandleOutputBuffer(void *aqData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer)
{    
    struct AQPlayerState* pAqData = (struct AQPlayerState*)aqData;
    MusicManager* pMusicManager = (MusicManager*)pAqData->musicManager;
    
    //[pAqData->lock lock];
    UInt32 numBytesReadFromFile;
    UInt32 numPackets = pAqData->mNumPacketsToRead;
    AudioFileReadPackets(pAqData->mAudioFile, false, &numBytesReadFromFile, pAqData->mPacketDescs, pAqData->mCurrentPacket, &numPackets, inBuffer->mAudioData);
    if (numPackets > 0)
    {
        inBuffer->mAudioDataByteSize = numBytesReadFromFile;
        AudioQueueEnqueueBuffer(pAqData->mQueue, inBuffer, (pAqData->mPacketDescs ? numPackets : 0), pAqData->mPacketDescs);
        pAqData->mCurrentPacket += numPackets;        
        //[pAqData->lock unlock];
    }
    else
    {        
        //[pAqData->lock unlock];
        [pMusicManager wantNextFile];
    }
}

void DeriveBufferSize (
                        AudioStreamBasicDescription *ASBDesc,                            // 1
                        UInt32                      maxPacketSize,                       // 2
                        Float64                     seconds,                             // 3
                        UInt32                      *outBufferSize,                      // 4
                        UInt32                      *outNumPacketsToRead                 // 5
                        ) {
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

// internals

- (MusicFile*)nextFileFor:(MusicFile*)file
{
    int i = [playlist indexOfObject:file.filename];
    if (i != NSNotFound && i + 1 < [playlist count])
    {
        return [[MusicFile alloc] initWithFilename:[playlist objectAtIndex:i + 1] locatedIn:file.cwd];
    }
    return nil;
}

- (NSString*)fsFilenameFor:(MusicFile*)file
{
    return [[[documentsDir stringByAppendingString:@"/"] stringByAppendingString:[[[file.cwd componentsJoinedByString:@"@"] stringByAppendingString:@"@"] stringByAppendingString:file.filename]] stringByAppendingString:@".mp3"];
}

- (NSString*)libraryFilenameFor:(MusicFile*)file
{
    return [[[file.cwd componentsJoinedByString:@"/"] stringByAppendingString:@"/"] stringByAppendingString:file.filename];
}

@end
