//
//  VideoProcess.m
//  OpenLive
//
//  Created by 汪洋 on 2019/4/16.
//  Copyright © 2019 Agora. All rights reserved.
//

// ------哎吖科技添加代码  开始------//

#import "VideoProcess.h"

#include <AgoraRtcEngineKit/IAgoraMediaEngine.h>
#include <AgoraRtcEngineKit/IAgoraRtcEngine.h>
#include <iostream>

#import <AiyaEffectSDK/AiyaEffectSDK.h>

static dispatch_queue_t videoFrameProcessQueue = dispatch_queue_create("AgoreVideoFrameProcessQueue", 0);

class AgoraVideoFrameObserver : public agora::media::IVideoFrameObserver
{
private:
    int bgra_len;
    bool stopQueue;
    
public:
    AYEffectHandler *handler;
    
    AgoraVideoFrameObserver()
    {
        stopQueue = false;
        
        handler = [[AYEffectHandler alloc] initWithProcessTexture:NO];
        [handler setBigEye:0.2];
        [handler setSlimFace:0.2];
        [handler setSmooth:1];
    }
    
    virtual bool onCaptureVideoFrame(VideoFrame& videoFrame) override
    {
        dispatch_sync(videoFrameProcessQueue, ^{
            
            if (stopQueue) {
                std::cout << "onCaptureVideoFrame error : Queue has stopped" << std::endl;
                return;
            }
            
            EAGLContext *context = [EAGLContext currentContext];
            if (videoFrame.rotation == 0) {
                [handler setRotateMode:kAYGPUImageFlipVertical];
            } else if (videoFrame.rotation == 90) {
                [handler setRotateMode:kAYGPUImageRotateRightFlipVertical];
            }

            [handler processWithYBuffer:videoFrame.yBuffer uBuffer:videoFrame.uBuffer vBuffer:videoFrame.vBuffer width:videoFrame.width height:videoFrame.height];
            [EAGLContext setCurrentContext:context];
            
        });
        
        return true;
    }
    virtual bool onRenderVideoFrame(unsigned int uid, VideoFrame& videoFrame) override
    {
        return true;
    }
    
    virtual ~AgoraVideoFrameObserver(){
        
        dispatch_sync(videoFrameProcessQueue, ^{
            bgra_len = 0;
            
            [handler destroy];
            handler = nil;
            
            stopQueue = true;
        });
    }
};

@interface VideoProcess () {
    AgoraVideoFrameObserver s_videoFrameObserver;
    agora::util::AutoPtr<agora::media::IMediaEngine> mediaEngine;
}

@end

@implementation VideoProcess

- (void)setEffectPath:(NSString *)path {
    [s_videoFrameObserver.handler setEffectPath:path];
}

- (void)registerVideoFrameObserver:(AgoraRtcEngineKit *)rtcEngine {
    agora::rtc::IRtcEngine* rtc_engine = (agora::rtc::IRtcEngine*)rtcEngine.getNativeHandle;
    
    mediaEngine.queryInterface(rtc_engine, agora::AGORA_IID_MEDIA_ENGINE);
    
    if (mediaEngine) {
        mediaEngine->registerVideoFrameObserver(&s_videoFrameObserver);
    }
}

- (void)unregisterVideoFrameObserver:(AgoraRtcEngineKit *)rtcEngine {
    agora::rtc::IRtcEngine* rtc_engine = (agora::rtc::IRtcEngine*)rtcEngine.getNativeHandle;
    
    mediaEngine.queryInterface(rtc_engine, agora::AGORA_IID_MEDIA_ENGINE);
    
    if (mediaEngine) {
        mediaEngine->registerVideoFrameObserver(NULL);
    }
}

- (void)dealloc {
    mediaEngine->release();
}

@end

// ------哎吖科技添加代码  结束------//
