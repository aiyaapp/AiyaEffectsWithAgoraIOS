//
//  AYRawBGRABufferUtil.h
//  AiyaEffectHandlerDemo
//
//  Created by 汪洋 on 2017/11/22.
//  Copyright © 2017年 深圳市哎吖科技有限公司. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>


/**
 使用opengl对BGRA数据进行旋转.
 */
@interface AYRawBGRABufferUtil : NSObject

/**
 原生的BGRA数据转换成CVPixelBuffer同时旋转

 @param inputBGRA 原生BGRA数据
 @param width 数据宽
 @param height 数据高
 @param angle 旋转的弧度
 @return 返回的CVPixelBuffer数据
 */
- (CVPixelBufferRef)rawBGRADataToCVPixelBuffer:(uint8_t *)inputBGRA width:(int)width height:(int)height rotate:(float)angle;


/**
 CVPixelBuffer转换成CVPixelBuffer同时旋转

 @param inputCVPixelBuffer CVPixelBuffer数据
 @param angle 旋转的弧度
 @return 返回的CVPixelBuffer数据
 */
- (CVPixelBufferRef)CVPixelBufferToCVPixelBuffer:(CVPixelBufferRef)inputCVPixelBuffer rotate:(float)angle;


/**
 释放资源
 */
- (void)releaseGLResources;
@end
