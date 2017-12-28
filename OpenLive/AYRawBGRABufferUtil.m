//
//  AYRawBGRABufferUtil.m
//  AiyaEffectHandlerDemo
//
//  Created by 汪洋 on 2017/11/22.
//  Copyright © 2017年 深圳市哎吖科技有限公司. All rights reserved.
//

#import "AYRawBGRABufferUtil.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <CoreMedia/CoreMedia.h>
#import <QuartzCore/QuartzCore.h>

static const NSString * kVertexShaderString =
@"attribute vec4 position;\n"
"attribute vec2 inputTextureCoordinate;\n"
"varying mediump vec2 v_texCoord;\n"
"uniform mediump mat4 transformMatrixUniform;\n"
"void main()\n"
"{\n"
"    gl_Position = transformMatrixUniform * position;\n"
"    v_texCoord = inputTextureCoordinate;\n"
"}\n";

static const NSString * kFragmentShaderString =
@"precision lowp float;\n"
"varying highp vec2 v_texCoord;\n"
"uniform sampler2D inputTexture;\n"
"void main()\n"
"{\n"
"    gl_FragColor = texture2D(inputTexture, v_texCoord);\n"
"}\n";

static const GLfloat squareVertices[] = {
    -1.0f, -1.0f,
    1.0f, -1.0f,
    -1.0f,  1.0f,
    1.0f,  1.0f,
};

static const GLfloat textureCoordinates[] = {
    0.0f, 0.0f,
    1.0f, 0.0f,
    0.0f, 1.0f,
    1.0f, 1.0f,
};

@interface AYRawBGRABufferUtil() {
    
    GLuint bgraProgram;
    GLint bgraPositionAttribute, bgraTextureCoordinateAttribute;
    GLint bgraTextureUniform;
    GLint bgraTransformMatrixUniform;
    
    GLuint outputCVPixelBufferFrameBuffer;
    CVPixelBufferRef outputCVPixelBuffer;
    CVOpenGLESTextureRef outputTextureRef;
    
    GLuint outputCVPixelBufferFrameBuffer2;
    CVPixelBufferRef outputCVPixelBuffer2;
    CVOpenGLESTextureRef outputTextureRef2;
    
    CVOpenGLESTextureCacheRef coreVideoTextureCache;
    
    EAGLContext *context;
    
}

@property (nonatomic, assign) int outputWidth;
@property (nonatomic, assign) int outputHeight;

@property (nonatomic, assign) int outputWidth2;
@property (nonatomic, assign) int outputHeight2;

@end

@implementation AYRawBGRABufferUtil

- (void)useContext{
    if (!context) {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        glDisable(GL_DEPTH_TEST);
    }

    [EAGLContext setCurrentContext:context];
}

- (CVPixelBufferRef)rawBGRADataToCVPixelBuffer:(uint8_t *)inputBGRA width:(int)width height:(int)height rotate:(float)angle{
    
    if (![EAGLContext currentContext]){
        [self useContext];
    }

    // 获取旋转矩阵
    CATransform3D transform3D = CATransform3DMakeRotation(angle, 0, 0, 1);
    GLfloat transformMatrix[16];
    transformMatrix[0] = (GLfloat)transform3D.m11;
    transformMatrix[1] = (GLfloat)transform3D.m21;
    transformMatrix[2] = (GLfloat)transform3D.m31;
    transformMatrix[3] = (GLfloat)transform3D.m41;
    transformMatrix[4] = (GLfloat)transform3D.m12;
    transformMatrix[5] = (GLfloat)transform3D.m22;
    transformMatrix[6] = (GLfloat)transform3D.m32;
    transformMatrix[7] = (GLfloat)transform3D.m42;
    transformMatrix[8] = (GLfloat)transform3D.m13;
    transformMatrix[9] = (GLfloat)transform3D.m23;
    transformMatrix[10] = (GLfloat)transform3D.m33;
    transformMatrix[11] = (GLfloat)transform3D.m43;
    transformMatrix[12] = (GLfloat)transform3D.m14;
    transformMatrix[13] = (GLfloat)transform3D.m24;
    transformMatrix[14] = (GLfloat)transform3D.m34;
    transformMatrix[15] = (GLfloat)transform3D.m44;

    int inputWidth = width;
    int inputHeight = height;

    int outputWidth;
    int outputHeight;

    if (fabs(angle - M_PI_2) < 0.0001 || fabs(angle + M_PI_2) < 0.0001) { // 如果旋转90度 或者 -90度, 导出的宽高进行交换
        outputWidth = inputHeight;
        outputHeight = inputWidth;
    }else {
        outputWidth = inputWidth;
        outputHeight = inputHeight;
    }

    if (outputWidth != self.outputWidth || outputHeight != self.outputHeight) {
        [self releaseBGRAGLResources];
        self.outputWidth = outputWidth;
        self.outputHeight = outputHeight;
    }

    // 创建导出时的CVPixelBuffer
    if (!outputCVPixelBufferFrameBuffer) {
        glGenFramebuffers(1, &outputCVPixelBufferFrameBuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, outputCVPixelBufferFrameBuffer);

        CFDictionaryRef empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);

        CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, outputWidth, outputHeight, kCVPixelFormatType_32BGRA, attrs, &outputCVPixelBuffer);
        
        if (err){
            NSLog(@"Error at CVPixelBufferCreate %d", err);
        }
        
        CFRelease(attrs);
        CFRelease(empty);

        CVOpenGLESTextureCacheCreateTextureFromImage (kCFAllocatorDefault, [self coreVideoTextureCache], outputCVPixelBuffer, NULL, GL_TEXTURE_2D, GL_RGBA, outputWidth, outputHeight, GL_BGRA, GL_UNSIGNED_BYTE, 0, &outputTextureRef);
        glBindTexture(CVOpenGLESTextureGetTarget(outputTextureRef), CVOpenGLESTextureGetName(outputTextureRef));
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(outputTextureRef), 0);
        glBindTexture(GL_TEXTURE_2D, 0);
    }

    // 生成输入的纹理
    GLuint inputTexture;
    glActiveTexture(GL_TEXTURE1);
    glGenTextures(1, &inputTexture);
    glBindTexture(GL_TEXTURE_2D, inputTexture);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, inputWidth, inputHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, inputBGRA);
    glBindTexture(GL_TEXTURE_2D, 0);

    // 渲染YUV数据到一个BGRA格式的CVPixelBuffer上
    if (!bgraProgram) {
        bgraProgram = [self createProgramWithVert:kVertexShaderString frag:kFragmentShaderString];
        bgraPositionAttribute = glGetAttribLocation(bgraProgram, [@"position" UTF8String]);
        bgraTextureCoordinateAttribute = glGetAttribLocation(bgraProgram, [@"inputTextureCoordinate" UTF8String]);
        bgraTextureUniform = glGetUniformLocation(bgraProgram, [@"inputTexture" UTF8String]);
        bgraTransformMatrixUniform = glGetUniformLocation(bgraProgram, [@"transformMatrixUniform" UTF8String]);
    }

    glUseProgram(bgraProgram);
    glBindFramebuffer(GL_FRAMEBUFFER, outputCVPixelBufferFrameBuffer);

    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, inputTexture);
    glUniform1i(bgraTextureUniform, 1);

    glUniformMatrix4fv(bgraTransformMatrixUniform, 1, GL_FALSE, transformMatrix);

    glEnableVertexAttribArray(bgraPositionAttribute);
    glEnableVertexAttribArray(bgraTextureCoordinateAttribute);
    glVertexAttribPointer(bgraPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(bgraTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);

    glViewport(0, 0, outputWidth, outputHeight);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glFinish();

    if (inputTexture) {
        glDeleteTextures(1, &inputTexture);
        inputTexture = 0;
    }
    
    return outputCVPixelBuffer;
}

- (CVPixelBufferRef)CVPixelBufferToCVPixelBuffer:(CVPixelBufferRef)inputCVPixelBuffer rotate:(float)angle{
    
    if (![EAGLContext currentContext]){
        [self useContext];
    }
    
    // 获取旋转矩阵
    CATransform3D transform3D = CATransform3DMakeRotation(angle, 0, 0, 1);
    GLfloat transformMatrix[16];
    transformMatrix[0] = (GLfloat)transform3D.m11;
    transformMatrix[1] = (GLfloat)transform3D.m21;
    transformMatrix[2] = (GLfloat)transform3D.m31;
    transformMatrix[3] = (GLfloat)transform3D.m41;
    transformMatrix[4] = (GLfloat)transform3D.m12;
    transformMatrix[5] = (GLfloat)transform3D.m22;
    transformMatrix[6] = (GLfloat)transform3D.m32;
    transformMatrix[7] = (GLfloat)transform3D.m42;
    transformMatrix[8] = (GLfloat)transform3D.m13;
    transformMatrix[9] = (GLfloat)transform3D.m23;
    transformMatrix[10] = (GLfloat)transform3D.m33;
    transformMatrix[11] = (GLfloat)transform3D.m43;
    transformMatrix[12] = (GLfloat)transform3D.m14;
    transformMatrix[13] = (GLfloat)transform3D.m24;
    transformMatrix[14] = (GLfloat)transform3D.m34;
    transformMatrix[15] = (GLfloat)transform3D.m44;
    
    int inputWidth = (int)CVPixelBufferGetWidth(inputCVPixelBuffer);
    int inputHeight = (int)CVPixelBufferGetHeight(inputCVPixelBuffer);
    
    int outputWidth;
    int outputHeight;
    
    if (fabs(angle - M_PI_2) < 0.0001 || fabs(angle + M_PI_2) < 0.0001) { // 如果旋转90度 或者 -90度, 导出的宽高进行交换
        outputWidth = inputHeight;
        outputHeight = inputWidth;
    }else {
        outputWidth = inputWidth;
        outputHeight = inputHeight;
    }
    
    if (outputWidth != self.outputWidth2 || outputHeight != self.outputHeight2) {
        [self releaseBGRAGLResources2];
        self.outputWidth2 = outputWidth;
        self.outputHeight2 = outputHeight;
    }
    
    // 创建导出时的CVPixelBuffer
    if (!outputCVPixelBufferFrameBuffer2) {
        glGenFramebuffers(1, &outputCVPixelBufferFrameBuffer2);
        glBindFramebuffer(GL_FRAMEBUFFER, outputCVPixelBufferFrameBuffer2);
        
        CFDictionaryRef empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);
        
        CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, outputWidth, outputHeight, kCVPixelFormatType_32BGRA, attrs, &outputCVPixelBuffer2);
        
        if (err){
            NSLog(@"Error at CVPixelBufferCreate %d", err);
        }
        
        CFRelease(attrs);
        CFRelease(empty);
        
        CVOpenGLESTextureCacheCreateTextureFromImage (kCFAllocatorDefault, [self coreVideoTextureCache], outputCVPixelBuffer2, NULL, GL_TEXTURE_2D, GL_RGBA, outputWidth, outputHeight, GL_BGRA, GL_UNSIGNED_BYTE, 0, &outputTextureRef2);
        glBindTexture(CVOpenGLESTextureGetTarget(outputTextureRef2), CVOpenGLESTextureGetName(outputTextureRef2));
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(outputTextureRef2), 0);
        glBindTexture(GL_TEXTURE_2D, 0);
    }
    
    // 生成输入的纹理
    GLuint inputTexture;
    glActiveTexture(GL_TEXTURE1);
    glGenTextures(1, &inputTexture);
    glBindTexture(GL_TEXTURE_2D, inputTexture);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    CVPixelBufferLockBaseAddress(inputCVPixelBuffer, 0);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)CVPixelBufferGetBytesPerRow(inputCVPixelBuffer) / 4, inputHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(inputCVPixelBuffer));
    CVPixelBufferUnlockBaseAddress(inputCVPixelBuffer, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    // 渲染YUV数据到一个BGRA格式的CVPixelBuffer上
    if (!bgraProgram) {
        bgraProgram = [self createProgramWithVert:kVertexShaderString frag:kFragmentShaderString];
        bgraPositionAttribute = glGetAttribLocation(bgraProgram, [@"position" UTF8String]);
        bgraTextureCoordinateAttribute = glGetAttribLocation(bgraProgram, [@"inputTextureCoordinate" UTF8String]);
        bgraTextureUniform = glGetUniformLocation(bgraProgram, [@"inputTexture" UTF8String]);
        bgraTransformMatrixUniform = glGetUniformLocation(bgraProgram, [@"transformMatrixUniform" UTF8String]);
    }
    
    glUseProgram(bgraProgram);
    glBindFramebuffer(GL_FRAMEBUFFER, outputCVPixelBufferFrameBuffer2);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, inputTexture);
    glUniform1i(bgraTextureUniform, 1);
    
    glUniformMatrix4fv(bgraTransformMatrixUniform, 1, GL_FALSE, transformMatrix);
    
    GLfloat textureCoordinates[8];
    textureCoordinates[0] = 0.0f;
    textureCoordinates[1] = 0.0f;
    textureCoordinates[2] = 1.0f - ((CVPixelBufferGetBytesPerRow(inputCVPixelBuffer)/4 - CVPixelBufferGetWidth(inputCVPixelBuffer)) / (float)CVPixelBufferGetWidth(inputCVPixelBuffer));
    textureCoordinates[3] = 0.0f;
    textureCoordinates[4] = 0.0f;
    textureCoordinates[5] = 1.0f;
    textureCoordinates[6] = 1.0f - ((CVPixelBufferGetBytesPerRow(inputCVPixelBuffer)/4 - CVPixelBufferGetWidth(inputCVPixelBuffer)) / (float)CVPixelBufferGetWidth(inputCVPixelBuffer));
    textureCoordinates[7] = 1.0f;
    
    glEnableVertexAttribArray(bgraPositionAttribute);
    glEnableVertexAttribArray(bgraTextureCoordinateAttribute);
    glVertexAttribPointer(bgraPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(bgraTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glViewport(0, 0, outputWidth, outputHeight);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glFinish();
    
    if (inputTexture) {
        glDeleteTextures(1, &inputTexture);
        inputTexture = 0;
    }

    return outputCVPixelBuffer2;
}

- (void)releaseBGRAGLResources{
    if (outputCVPixelBufferFrameBuffer) {
        glDeleteFramebuffers(1, &outputCVPixelBufferFrameBuffer);
        outputCVPixelBufferFrameBuffer = 0;
    }
    
    if (outputCVPixelBuffer) {
        CFRelease(outputCVPixelBuffer);
        outputCVPixelBuffer = NULL;
    }
    
    if (outputTextureRef) {
        CFRelease(outputTextureRef);
        outputTextureRef = NULL;
    }
    
}

- (void)releaseBGRAGLResources2{
    if (outputCVPixelBufferFrameBuffer2) {
        glDeleteFramebuffers(1, &outputCVPixelBufferFrameBuffer2);
        outputCVPixelBufferFrameBuffer2 = 0;
    }
    
    if (outputCVPixelBuffer2) {
        CFRelease(outputCVPixelBuffer2);
        outputCVPixelBuffer2 = NULL;
    }
    
    if (outputTextureRef2) {
        CFRelease(outputTextureRef2);
        outputTextureRef2 = NULL;
    }
}

- (void)releaseGLResources{
    
    [self releaseBGRAGLResources];
    [self releaseBGRAGLResources2];

    if (coreVideoTextureCache) {
        CFRelease(coreVideoTextureCache);
        coreVideoTextureCache = NULL;
    }
}

- (CVOpenGLESTextureCacheRef)coreVideoTextureCache {
    if (coreVideoTextureCache == NULL){
        EAGLContext* context = [EAGLContext currentContext];
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, context, NULL, &coreVideoTextureCache);
        
        if (err){
            NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
        }
    }
    
    return coreVideoTextureCache;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type string:(const NSString *)shaderString{
    
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[shaderString UTF8String];
    if (!source){
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    
    if (status != GL_TRUE) {
        GLint logLength;
        glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0){
            GLchar *log = (GLchar *)malloc(logLength);
            glGetShaderInfoLog(*shader, logLength, &logLength, log);
            NSLog(@"Failed to compile shader %s", log);
            free(log);
        }
    }
    
    return status == GL_TRUE;
}

- (GLuint)createProgramWithVert:(const NSString *)vShaderString frag:(const NSString *)fShaderString{
    
    GLuint program = glCreateProgram();
    GLuint vertShader, fragShader;
    if (![self compileShader:&vertShader
                        type:GL_VERTEX_SHADER
                      string:vShaderString]){
        NSLog(@"Failed to compile vertex shader");
    }
    
    if (![self compileShader:&fragShader
                        type:GL_FRAGMENT_SHADER
                      string:fShaderString]){
        NSLog(@"Failed to compile fragment shader");
    }
    
    glAttachShader(program, vertShader);
    glAttachShader(program, fragShader);
    
    GLint status;
    
    glLinkProgram(program);
    
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE)
        NSLog(@"Failed to link shader");
    
    if (vertShader)
    {
        glDeleteShader(vertShader);
        vertShader = 0;
    }
    if (fragShader)
    {
        glDeleteShader(fragShader);
        fragShader = 0;
    }
    
    return program;
}

@end
