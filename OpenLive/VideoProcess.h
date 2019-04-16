//
//  VideoProcess.h
//  OpenLive
//
//  Created by 汪洋 on 2019/4/16.
//  Copyright © 2019 Agora. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AgoraRtcEngineKit/AgoraRtcEngineKit.h>

@interface VideoProcess : NSObject

- (void)setEffectPath:(NSString *)path;

- (void)registerVideoFrameObserver:(AgoraRtcEngineKit *)rtcEngine;

- (void)unregisterVideoFrameObserver:(AgoraRtcEngineKit *)rtcEngine;

@end
