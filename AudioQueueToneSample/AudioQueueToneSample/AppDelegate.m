#import "AppDelegate.h"
#import <AudioToolbox/AudioToolbox.h>

static const int kSampleRate = 44100;
static const int kFramesPerBuffer = 1024;
static const int kNumBuffers = 3;

@implementation AppDelegate
{
    AudioStreamBasicDescription _outpufFormat;
    AudioQueueRef _audioQueue;
    NSUInteger _frameIndex;
}

static void audioQueueOutputCallback(void *inUserData,
                                     AudioQueueRef inAQ,
                                     AudioQueueBufferRef inBuffer)
{
    AppDelegate *object = (__bridge AppDelegate *)inUserData;
    [object audioQueueOutputWithAudioQueue:inAQ buffer:inBuffer];
}

- (void)audioQueueOutputWithAudioQueue:(AudioQueueRef)inAQ buffer:(AudioQueueBufferRef)inBuffer
{
    NSAssert(inBuffer->mAudioDataBytesCapacity <= _outpufFormat.mBytesPerFrame * kFramesPerBuffer, @"!");

    inBuffer->mAudioDataByteSize = _outpufFormat.mBytesPerFrame * kFramesPerBuffer;

    float freq = 440.0f;
    float phasePerSample = freq / kSampleRate;
    int16_t *sampleBuffer = (int16_t *)inBuffer->mAudioData;

    for (int i = 0; i < kFramesPerBuffer; i++) {
        *sampleBuffer = (int16_t)((sinf((float)_frameIndex * phasePerSample * (M_PI*2.0f))) * 32767.0f);
        sampleBuffer++;

        _frameIndex++;
    }

    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

- (void)setupAudioQueue
{
    _frameIndex = 0;

    memset(&_outpufFormat, 0, sizeof(_outpufFormat));

    _outpufFormat.mFormatID = kAudioFormatLinearPCM;
    _outpufFormat.mSampleRate = kSampleRate;
    _outpufFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    _outpufFormat.mBitsPerChannel = 16;
    _outpufFormat.mChannelsPerFrame = 1;
    _outpufFormat.mBytesPerFrame = 2;
    _outpufFormat.mFramesPerPacket = 1;
    _outpufFormat.mBytesPerPacket = 2;

    OSStatus status =
    AudioQueueNewOutput(&_outpufFormat,
                        audioQueueOutputCallback,
                        (__bridge void *)self,
                        CFRunLoopGetCurrent(),
                        kCFRunLoopCommonModes,
                        0,
                        &_audioQueue);

    UInt32 bufferSize = kFramesPerBuffer * _outpufFormat.mBytesPerFrame;

    for (int i = 0; i < kNumBuffers; i++) {
        AudioQueueBufferRef buffer;
        status = AudioQueueAllocateBuffer(_audioQueue, bufferSize, &buffer);
        // AudioQueueを破棄すると関連づいているBufferも破棄される

        // Bufferにデータを入れておかないとAudioQueueStartしてもコールバックが呼ばれない
        [self audioQueueOutputWithAudioQueue:_audioQueue buffer:buffer];
    }

    status = AudioQueueStart(_audioQueue, NULL);
}

#pragma mark -

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self setupAudioQueue];
    return YES;
}

@end
