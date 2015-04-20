//
//  JSDTMFToneGenerator.h
//  JSDTMFToneGenerator
//
//  Created on 11/04/2015.
//
//  Copyright (c) 2015 Jalamanta
//
//  This software is provided 'as-is', without any express or implied
//  warranty. In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgement in the product documentation would be
//     appreciated but is not required.
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//  3. This notice may not be removed or altered from any source distribution.
//

#import <AVFoundation/AVFoundation.h>

#import "JSDTMFToneGenerator.h"

static const AVAudioFrameCount kSamplesPerBuffer = 1024;

@interface JSDTMFToneGenerator ()

@property (nonatomic, readonly) AVAudioEngine *audioEngine;
@property (nonatomic, readonly) AVAudioMixerNode *mixerNode;
@property (nonatomic, readonly) AVAudioPlayerNode *playerOneNode;
@property (nonatomic, readonly) AVAudioPlayerNode *playerTwoNode;
@property (nonatomic, readonly) AVAudioPCMBuffer* pcmBufferOne;
@property (nonatomic, readonly) AVAudioPCMBuffer* pcmBufferTwo;

@end


@implementation JSDTMFToneGenerator

-(NSUInteger)greatestCommonDivisor:(NSUInteger)firstValue secondValue:(NSUInteger)secondValue
{
    if (firstValue == 0 && secondValue == 0)
        return 0;
    
    NSUInteger r;
    while(secondValue)
    {
        r = firstValue % secondValue;
        firstValue = secondValue;
        secondValue = r;
    }
    return firstValue;
}

-(instancetype)initWithFrequency:(NSUInteger)frequency;
{
    self = [super init];
    
    if (self)
    {
        _audioEngine = [[AVAudioEngine alloc] init];
        
        _mixerNode = _audioEngine.mainMixerNode;
        
        _playerOneNode = [[AVAudioPlayerNode alloc] init];
        [_audioEngine attachNode:_playerOneNode];
        
        [_audioEngine connect:_playerOneNode to:_mixerNode format:[_playerOneNode outputFormatForBus:0]];
        
        _pcmBufferOne = [self createAudioBufferWithLoopableSineWaveFrequency:frequency];
        
        NSError *error = nil;
        [_audioEngine startAndReturnError:&error];
        NSLog(@"error: %@", error);
    }
    
    return self;
}

-(instancetype)initWithDTMFfrequency1:(NSUInteger)frequency1 frequency2:(NSUInteger)frequency2
{
    self = [super init];
    
    if (self)
    {
        _audioEngine = [[AVAudioEngine alloc] init];
        
        _mixerNode = _audioEngine.mainMixerNode;
        
        _playerOneNode = [[AVAudioPlayerNode alloc] init];
        [_audioEngine attachNode:_playerOneNode];
        
        [_audioEngine connect:_playerOneNode to:_mixerNode format:[_playerOneNode outputFormatForBus:0]];
        
        _pcmBufferOne = [self createAudioBufferWithLoopableSineWaveFrequency:frequency1];
        if (frequency2 > 0)
        {
            _playerTwoNode = [[AVAudioPlayerNode alloc] init];
            [_audioEngine attachNode:_playerTwoNode];
            
            [_audioEngine connect:_playerTwoNode to:_mixerNode format:[_playerTwoNode outputFormatForBus:0]];
            
            _pcmBufferTwo = [self createAudioBufferWithLoopableSineWaveFrequency:frequency2];
        }
        
        NSError *error = nil;
        [_audioEngine startAndReturnError:&error];
        NSLog(@"error: %@", error);
    }
    
    return self;
}

-(AVAudioPCMBuffer*)createAudioBufferWithLoopableSineWaveFrequency:(NSUInteger)frequency
{
     AVAudioFormat *mixerFormat = [_mixerNode outputFormatForBus:0];
    
    double sampleRate = mixerFormat.sampleRate;
    double frameLength = kSamplesPerBuffer;
    
    // BM: Find the greatest common divisor so that we can determine the number of full cycles
    // BM: and size of buffer needed to make a loop of a sine wav at this frequency for this
    // BM: sampleRate.  Otherwise we hear pops and clicks in our loops.
    NSUInteger gcd = [self greatestCommonDivisor:frequency secondValue:mixerFormat.sampleRate];
    if (gcd != 0)
    {
        // NSUInteger numberOfCycles = frequency / gcd;
        frameLength = mixerFormat.sampleRate / gcd;
    }
    
    AVAudioPCMBuffer *pcmBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:mixerFormat frameCapacity:frameLength];
    pcmBuffer.frameLength = frameLength;
    
    float *leftChannel = pcmBuffer.floatChannelData[0];
    float *rightChannel = mixerFormat.channelCount == 2 ? pcmBuffer.floatChannelData[1] : nil;
    
    double increment = 2.0f * M_PI * frequency/sampleRate;
    double theta = 0.0f;
    for (NSUInteger i_sample=0; i_sample < pcmBuffer.frameLength; i_sample++)
    {
        CGFloat value = sinf( theta);
        
        theta += increment;
        
        if (theta > 2.0f * M_PI) theta -= (2.0f * M_PI);
        
        if (leftChannel)  leftChannel[i_sample] = value * .5f;
        if (rightChannel) rightChannel[i_sample] = value * .5f;
    }
    
    return pcmBuffer;
}

-(void)play
{
    
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
    
    if (self.audioEngine.isRunning == NO)
    {
        NSError *error = nil;
        [_audioEngine startAndReturnError:&error];
        NSLog(@"error: %@", error);   
    }
    
    if (_playerOneNode && _pcmBufferOne)
    {
        [_playerOneNode scheduleBuffer:_pcmBufferOne atTime:nil options:AVAudioPlayerNodeBufferLoops completionHandler:^{
            
        }];
        
        [_playerOneNode play];
    }

    if (_playerTwoNode && _pcmBufferTwo)
    {
        [_playerTwoNode scheduleBuffer:_pcmBufferTwo atTime:nil options:AVAudioPlayerNodeBufferLoops completionHandler:^{
            
        }];
        
        [_playerTwoNode play];
    }
    
    
}

-(void)stop
{
    [_playerOneNode stop];
    [_playerTwoNode stop];
}

@end

