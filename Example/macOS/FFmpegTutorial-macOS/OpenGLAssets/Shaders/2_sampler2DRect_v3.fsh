/*
     File: Shader.fsh
 Abstract: Fragment shader for converting Y/UV textures to RGB.
  Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2013 Apple Inc. All Rights Reserved.
 
 */

//https://stackoverflow.com/questions/8788049/shader-differences-on-ios
//ERROR: 0:51: 'mat3' : declaration must include a precision qualifier for type
//precision mediump float;
/*
 1、为什么使用 sampler2DRect 而不是 sampler2D ？
    解码数据放在了 CVPixelBufferRef 结构体里面了，要想直接渲染，需要先转成 IOSurfaceRef 然后
    借助 CGLTexImageIOSurface2D 实现纹理绑定。
    而 CGLTexImageIOSurface2D 需要使用 sampler2DRect 采样器，
    
    如果否则 creating IOSurface texture 失败
 
 2、OpenGL定义的 glTexImage2D 也可以做纹理绑定，可以使用 sampler2D，但是为了能够复用一个 shader 程序，因此选择使用 sampler2DRect
 
 3、采样器和纹理格式要对应，否则就会绿屏。
    sampler2D 采样器对应的纹理是 GL_TEXTURE_2D ，而 sampler2DRect 对应的纹理是 GL_TEXTURE_RECTANGLE。
 
 3、sampler2DRect 采样器的坐标不是[0,1]，而是纹理的原始尺寸 [w,h] ，如果坐标不对，很可能是黑屏，因为取不到相应的像素。
 
 */

#version 330

out vec4 FragColor;
uniform sampler2DRect SamplerY;
uniform sampler2DRect SamplerUV;
uniform vec2 textureDimensionY;
uniform vec2 textureDimensionUV;

uniform mat3 colorConversionMatrix;
in vec2 texCoordVarying;

void main()
{
    vec3 yuv;
    vec3 rgb;
    
    vec2 recTexCoordY  = texCoordVarying * textureDimensionY;
    vec2 recTexCoordUV = texCoordVarying * textureDimensionUV;
    
    //使用 r,g,b 都可以，a不行！
    yuv.x  = texture(SamplerY, recTexCoordY).r;
    //使用 ra,ga,ba 都可以！
    yuv.yz = texture(SamplerUV, recTexCoordUV).rg - vec2(0.5, 0.5);
    
//    yuv = vec3(1.0,1.0,1.0);
    rgb = colorConversionMatrix * yuv;
    FragColor = vec4(rgb, 1);
}
