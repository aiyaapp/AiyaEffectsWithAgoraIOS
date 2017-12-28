//
//  AYEffectHandler.h
//  AiyaEffectSDK
//
//  Created by 汪洋 on 2017/11/29.
//  Copyright © 2017年 深圳市哎吖科技有限公司. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#define AY_USE_TRACK    1
#define AY_USE_EFFECT   1
#define AY_USE_BEAUTY   1
#define AY_USE_BIGEYE_SLIMFACE 1

@interface AYEffectHandler : NSObject

#if AY_USE_EFFECT
/**
 设置特效,通过设置特效文件路径的方式,默认空值,空值表示取消渲染特效
 */
@property (nonatomic, strong) NSString *effectPath;

/**
 设置特效播放次数
 */
@property (nonatomic, assign) NSUInteger effectPlayCount;

/**
 暂停特效播放
 */
- (void)pauseEffect;

/**
 继续特效播放
 */
- (void)resumeEffect;

#endif

/**
 设置风格滤镜
 */
@property (nonatomic, strong) UIImage *style;
@property (nonatomic, assign) CGFloat intensityOfStyle;

#if AY_USE_BEAUTY
/**
 设置美颜强度 默认0 最高为1
 */
@property (nonatomic, assign) CGFloat beauty;
#endif

#if AY_USE_BIGEYE_SLIMFACE
/**
 设置大眼强度 默认0 最高为1
 */
@property (nonatomic, assign) CGFloat bigEye;

/**
 设置瘦脸强度 默认0 最高为1
 */
@property (nonatomic, assign) CGFloat slimFace;
#endif

/**
 设置特效是否要垂直翻转
 */
@property (nonatomic, assign) BOOL verticalFlip;

/**
 处理纹理数据

 @param texture 纹理数据
 @param width 宽度
 @param height 高度
 */
- (void)processWithTexture:(GLuint)texture width:(GLint)width height:(GLint)height;

/**
 处理BGRA数据
 
 @param pixelBuffer BGRA格式数据
 */
- (void)processWithPixelBuffer:(CVPixelBufferRef)pixelBuffer;


@end
