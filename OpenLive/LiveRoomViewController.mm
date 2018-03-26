//
//  LiveRoomViewController.m
//  OpenLive
//
//  Created by GongYuhua on 2016/9/12.
//  Copyright © 2016年 Agora. All rights reserved.
//

#import "LiveRoomViewController.h"
#import "VideoSession.h"
#import "VideoViewLayouter.h"
#import "KeyCenter.h"

// ------哎吖科技添加代码  开始------//

#include <AgoraRtcEngineKit/IAgoraMediaEngine.h>
#include <AgoraRtcEngineKit/IAgoraRtcEngine.h>
#include <iostream>
#include "libyuv.h"

#import <AiyaEffectSDK/AiyaEffectSDK.h>
#import "AYRawBGRABufferUtil.h"

NSString *effectPath = @"";

class AgoraVideoFrameObserver : public agora::media::IVideoFrameObserver
{
private:
    int bgra_len;
    uint8_t *bgra;
    
    AYEffectHandler *handler;
    AYRawBGRABufferUtil *bgraUtil;
public:
    virtual bool onCaptureVideoFrame(VideoFrame& videoFrame) override
    {
        
        int len = videoFrame.width * videoFrame.height * 4;
        
        if (bgra_len != len) {
            if (bgra != NULL) {
                free(bgra);
                std::cout << "free (bgra)" << std::endl;
            }
            
            std::cout << "malloc (bgra)" << std::endl;
            bgra = (uint8_t *)malloc(sizeof(uint8_t)*len);
            bgra_len = len;
        }
        
        int bgra_stride = videoFrame.width * 4;
        
        libyuv::I420ToARGB((uint8_t *)videoFrame.yBuffer, videoFrame.yStride, (uint8_t *)videoFrame.uBuffer, videoFrame.uStride, (uint8_t *)videoFrame.vBuffer, videoFrame.vStride, bgra, bgra_stride, videoFrame.width, videoFrame.height);
        
        if (!bgraUtil) {
            bgraUtil = [AYRawBGRABufferUtil new];
        }
        
        CVPixelBufferRef bgraCVPixelBuffer = [bgraUtil rawBGRADataToCVPixelBuffer:bgra width:videoFrame.width height:videoFrame.height rotate:-M_PI_2];
        
        EAGLContext *context = [EAGLContext currentContext];
        if (handler == NULL) {
            handler = [[AYEffectHandler alloc]init];
        }

        [handler setBigEye:0.2];
        [handler setSlimFace:0.2];
        [handler setSmooth:1];
        [handler setEffectPath:effectPath];
        [handler processWithPixelBuffer:bgraCVPixelBuffer];
        [EAGLContext setCurrentContext:context];
        
        bgraCVPixelBuffer = [bgraUtil CVPixelBufferToCVPixelBuffer:bgraCVPixelBuffer rotate:M_PI_2];
        
        CVPixelBufferLockBaseAddress(bgraCVPixelBuffer, 0);
        
        void *data = CVPixelBufferGetBaseAddress(bgraCVPixelBuffer);
        memcpy(bgra, data, videoFrame.width * videoFrame.height * 4);
        
        CVPixelBufferUnlockBaseAddress(bgraCVPixelBuffer, 0);
        
        libyuv::ARGBToI420(bgra, bgra_stride, (uint8_t *)videoFrame.yBuffer, videoFrame.yStride, (uint8_t *)videoFrame.uBuffer, videoFrame.uStride, (uint8_t *)videoFrame.vBuffer, videoFrame.vStride,videoFrame.width, videoFrame.height);
        
        
        return true;
    }
    virtual bool onRenderVideoFrame(unsigned int uid, VideoFrame& videoFrame) override
    {
        return true;
    }
    
    virtual ~AgoraVideoFrameObserver(){
        if (bgra != NULL) {
            free(bgra);
            std::cout << "free (bgra)" << std::endl;
        }
        bgra = NULL;
    }
};

// ------哎吖科技添加代码  结束------//


@interface LiveRoomViewController () <AgoraRtcEngineDelegate>{
// ------哎吖科技添加代码  开始------//
    
    AgoraVideoFrameObserver s_videoFrameObserver;
    agora::util::AutoPtr<agora::media::IMediaEngine> mediaEngine;
// ------哎吖科技添加代码  结束------//
}
@property (weak, nonatomic) IBOutlet UILabel *roomNameLabel;
@property (weak, nonatomic) IBOutlet UIView *remoteContainerView;
@property (weak, nonatomic) IBOutlet UIButton *broadcastButton;
@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *sessionButtons;
@property (weak, nonatomic) IBOutlet UIButton *audioMuteButton;
@property (weak, nonatomic) IBOutlet UIButton *enhancerButton;

@property (strong, nonatomic) AgoraRtcEngineKit *rtcEngine;
@property (assign, nonatomic) BOOL isBroadcaster;
@property (assign, nonatomic) BOOL isMuted;
@property (assign, nonatomic) BOOL shouldEnhancer;
@property (strong, nonatomic) NSMutableArray<VideoSession *> *videoSessions;
@property (strong, nonatomic) VideoSession *fullSession;
@property (strong, nonatomic) VideoViewLayouter *viewLayouter;
@end

@implementation LiveRoomViewController
- (BOOL)isBroadcaster {
    return self.clientRole == AgoraRtc_ClientRole_Broadcaster;
}

- (VideoViewLayouter *)viewLayouter {
    if (!_viewLayouter) {
        _viewLayouter = [[VideoViewLayouter alloc] init];
    }
    return _viewLayouter;
}

- (void)setClientRole:(AgoraRtcClientRole)clientRole {
    _clientRole = clientRole;
    
    if (self.isBroadcaster) {
        self.shouldEnhancer = YES;
    }
    [self updateButtonsVisiablity];
}

- (void)setIsMuted:(BOOL)isMuted {
    _isMuted = isMuted;
    [self.rtcEngine muteLocalAudioStream:isMuted];
    [self.audioMuteButton setImage:[UIImage imageNamed:(isMuted ? @"btn_mute_cancel" : @"btn_mute")] forState:UIControlStateNormal];
}

- (void)setVideoSessions:(NSMutableArray<VideoSession *> *)videoSessions {
    _videoSessions = videoSessions;
    if (self.remoteContainerView) {
        [self updateInterfaceWithAnimation:YES];
    }
}

- (void)setFullSession:(VideoSession *)fullSession {
    _fullSession = fullSession;
    if (self.remoteContainerView) {
        [self updateInterfaceWithAnimation:YES];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
// ------哎吖科技添加代码  开始------//
    // license state notification
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(licenseMessage:) name:AiyaLicenseNotification object:nil];
    
    // render state notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(aiyaMessage:) name:AiyaMessageNotification object:nil];
    
    [AYLicenseManager initLicense:@"cc13acdbebf941af99a749aa505a2e05"];
    effectPath = [[NSBundle mainBundle] pathForResource:@"meta" ofType:@"json" inDirectory:@"gougou"];
// ------哎吖科技添加代码  结束------//

    self.videoSessions = [[NSMutableArray alloc] init];
    
    self.roomNameLabel.text = self.roomName;
    [self updateButtonsVisiablity];
    
    [self loadAgoraKit];
}

- (IBAction)doSwitchCameraPressed:(UIButton *)sender {
    [self.rtcEngine switchCamera];
}

- (IBAction)doMutePressed:(UIButton *)sender {
    self.isMuted = !self.isMuted;
}

- (IBAction)doBroadcastPressed:(UIButton *)sender {
    if (self.isBroadcaster) {
        self.clientRole = AgoraRtc_ClientRole_Audience;
        if (self.fullSession.uid == 0) {
            self.fullSession = nil;
        }
    } else {
        self.clientRole = AgoraRtc_ClientRole_Broadcaster;
    }
    
    [self.rtcEngine setClientRole:self.clientRole withKey:nil];
    [self updateInterfaceWithAnimation:YES];
}

- (IBAction)doDoubleTapped:(UITapGestureRecognizer *)sender {
    if (!self.fullSession) {
        VideoSession *tappedSession = [self.viewLayouter responseSessionOfGesture:sender inSessions:self.videoSessions inContainerView:self.remoteContainerView];
        if (tappedSession) {
            self.fullSession = tappedSession;
        }
    } else {
        self.fullSession = nil;
    }
}

- (IBAction)doLeavePressed:(UIButton *)sender {
    [self leaveChannel];
}

- (void)updateButtonsVisiablity {
    [self.broadcastButton setImage:[UIImage imageNamed:self.isBroadcaster ? @"btn_join_cancel" : @"btn_join"] forState:UIControlStateNormal];
    for (UIButton *button in self.sessionButtons) {
        button.hidden = !self.isBroadcaster;
    }
}

- (void)leaveChannel {
    [self setIdleTimerActive:YES];
    
    [self.rtcEngine setupLocalVideo:nil];
    [self.rtcEngine leaveChannel:nil];
    if (self.isBroadcaster) {
        [self.rtcEngine stopPreview];
    }
    
    for (VideoSession *session in self.videoSessions) {
        [session.hostingView removeFromSuperview];
    }
    [self.videoSessions removeAllObjects];
    
    if ([self.delegate respondsToSelector:@selector(liveVCNeedClose:)]) {
        [self.delegate liveVCNeedClose:self];
    }
}

- (void)setIdleTimerActive:(BOOL)active {
    [UIApplication sharedApplication].idleTimerDisabled = !active;
}

- (void)alertString:(NSString *)string {
    if (!string.length) {
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:string preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)updateInterfaceWithAnimation:(BOOL)animation {
    if (animation) {
        [UIView animateWithDuration:0.3 animations:^{
            [self updateInterface];
            [self.view layoutIfNeeded];
        }];
    } else {
        [self updateInterface];
    }
}

- (void)updateInterface {
    NSArray *displaySessions;
    if (!self.isBroadcaster && self.videoSessions.count) {
        displaySessions = [self.videoSessions subarrayWithRange:NSMakeRange(1, self.videoSessions.count - 1)];
    } else {
        displaySessions = [self.videoSessions copy];
    }
    
    [self.viewLayouter layoutSessions:displaySessions fullSession:self.fullSession inContainer:self.remoteContainerView];
    [self setStreamTypeForSessions:displaySessions fullSession:self.fullSession];
}

- (void)setStreamTypeForSessions:(NSArray<VideoSession *> *)sessions fullSession:(VideoSession *)fullSession {
    if (fullSession) {
        for (VideoSession *session in sessions) {
            [self.rtcEngine setRemoteVideoStream:session.uid type:(session == self.fullSession ? AgoraRtc_VideoStream_High : AgoraRtc_VideoStream_Low)];
        }
    } else {
        for (VideoSession *session in sessions) {
            [self.rtcEngine setRemoteVideoStream:session.uid type:AgoraRtc_VideoStream_High];
        }
    }
}

- (void)addLocalSession {
    VideoSession *localSession = [VideoSession localSession];
    [self.videoSessions addObject:localSession];
    [self.rtcEngine setupLocalVideo:localSession.canvas];
    [self updateInterfaceWithAnimation:YES];
}

- (VideoSession *)fetchSessionOfUid:(NSUInteger)uid {
    for (VideoSession *session in self.videoSessions) {
        if (session.uid == uid) {
            return session;
        }
    }
    return nil;
}

- (VideoSession *)videoSessionOfUid:(NSUInteger)uid {
    VideoSession *fetchedSession = [self fetchSessionOfUid:uid];
    if (fetchedSession) {
        return fetchedSession;
    } else {
        VideoSession *newSession = [[VideoSession alloc] initWithUid:uid];
        [self.videoSessions addObject:newSession];
        [self updateInterfaceWithAnimation:YES];
        return newSession;
    }
}

//MARK: - Agora Media SDK
- (void)loadAgoraKit {
    self.rtcEngine = [AgoraRtcEngineKit sharedEngineWithAppId:[KeyCenter AppId] delegate:self];
    [self.rtcEngine setChannelProfile:AgoraRtc_ChannelProfile_LiveBroadcasting];
    [self.rtcEngine enableDualStreamMode:YES];
    [self.rtcEngine enableVideo];
    [self.rtcEngine setVideoProfile:self.videoProfile swapWidthAndHeight:YES];
    [self.rtcEngine setClientRole:self.clientRole withKey:nil];
    
// ------哎吖科技添加代码  开始------//

    agora::rtc::IRtcEngine* rtc_engine = (agora::rtc::IRtcEngine*)self.rtcEngine.getNativeHandle;

    mediaEngine.queryInterface(*rtc_engine, agora::rtc::AGORA_IID_MEDIA_ENGINE);
    
    if (mediaEngine)
    {
        mediaEngine->registerVideoFrameObserver(&s_videoFrameObserver);
    }
// ------哎吖科技添加代码  结束------//

    if (self.isBroadcaster) {
        [self.rtcEngine startPreview];
    }
    
    [self addLocalSession];
    
    int code = [self.rtcEngine joinChannelByKey:nil channelName:self.roomName info:nil uid:0 joinSuccess:nil];
    if (code == 0) {
        [self setIdleTimerActive:NO];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self alertString:[NSString stringWithFormat:@"Join channel failed: %d", code]];
        });
    }
    
    if (self.isBroadcaster) {
        self.shouldEnhancer = YES;
    }
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine firstRemoteVideoDecodedOfUid:(NSUInteger)uid size:(CGSize)size elapsed:(NSInteger)elapsed {
    VideoSession *userSession = [self videoSessionOfUid:uid];
    [self.rtcEngine setupRemoteVideo:userSession.canvas];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine firstLocalVideoFrameWithSize:(CGSize)size elapsed:(NSInteger)elapsed {
    if (self.videoSessions.count) {
        [self updateInterfaceWithAnimation:NO];
    }
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didOfflineOfUid:(NSUInteger)uid reason:(AgoraRtcUserOfflineReason)reason {
    VideoSession *deleteSession;
    for (VideoSession *session in self.videoSessions) {
        if (session.uid == uid) {
            deleteSession = session;
        }
    }
    
    if (deleteSession) {
        [self.videoSessions removeObject:deleteSession];
        [deleteSession.hostingView removeFromSuperview];
        [self updateInterfaceWithAnimation:YES];
        
        if (deleteSession == self.fullSession) {
            self.fullSession = nil;
        }
    }
}

// ------哎吖科技添加代码  开始------//

- (void)licenseMessage:(NSNotification *)notifi{
    AiyaLicenseResult result = (AiyaLicenseResult)[notifi.userInfo[AiyaLicenseNotificationUserInfoKey] integerValue];
    switch (result) {
        case AiyaLicenseSuccess:
            NSLog(@"License 验证成功");
            break;
        case AiyaLicenseFail:
            NSLog(@"License 验证失败");
            break;
    }
}

- (void)aiyaMessage:(NSNotification *)notifi{
    
    NSString *message = notifi.userInfo[AiyaMessageNotificationUserInfoKey];
    NSLog(@"message : %@",message);
}

// ------哎吖科技添加代码  结束------//

@end
