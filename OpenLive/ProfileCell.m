//
//  ProfileCell.m
//  OpenLive
//
//  Created by GongYuhua on 2016/9/12.
//  Copyright © 2016年 Agora. All rights reserved.
//

#import "ProfileCell.h"

@interface ProfileCell()
@property (weak, nonatomic) IBOutlet UILabel *resLabel;
@property (weak, nonatomic) IBOutlet UILabel *frameLabel;
@property (weak, nonatomic) IBOutlet UILabel *bitRateLabel;
@end

@implementation ProfileCell

- (void)updateWithProfile:(AgoraRtcVideoProfile)profile isSelected:(BOOL)isSelected {
    self.resLabel.text = [self resolutionOfProfile:profile];
    self.frameLabel.text = [self fpsOfProfile:profile];
    self.bitRateLabel.text = [self bitRateOfProfile:profile];
    self.backgroundColor = isSelected ? [UIColor colorWithRed:0 green:0 blue:0.5 alpha:0.3] : [UIColor whiteColor];
}

- (NSString *)resolutionOfProfile:(AgoraRtcVideoProfile)profile {
    switch (profile) {
        case AgoraRtc_VideoProfile_120P: return @"160×120"; break;
        case AgoraRtc_VideoProfile_180P: return @"320×180"; break;
        case AgoraRtc_VideoProfile_240P: return @"320×240"; break;
        case AgoraRtc_VideoProfile_360P: return @"640×360"; break;
        case AgoraRtc_VideoProfile_480P: return @"640×480"; break;
        case AgoraRtc_VideoProfile_720P: return @"1280×720"; break;
        default: return @""; break;
    }
}

- (NSString *)fpsOfProfile:(AgoraRtcVideoProfile)profile {
    return @"15";
}

- (NSString *)bitRateOfProfile:(AgoraRtcVideoProfile)profile {
    switch (profile) {
        case AgoraRtc_VideoProfile_120P: return @"65"; break;
        case AgoraRtc_VideoProfile_180P: return @"140"; break;
        case AgoraRtc_VideoProfile_240P: return @"200"; break;
        case AgoraRtc_VideoProfile_360P: return @"400"; break;
        case AgoraRtc_VideoProfile_480P: return @"500"; break;
        case AgoraRtc_VideoProfile_720P: return @"1130"; break;
        default: return @""; break;
    }
}

@end
