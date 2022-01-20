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

 https://people.freedesktop.org/~marcheu/extensions/APPLE/ycbcr_422.html
 
 */

//https://stackoverflow.com/questions/8788049/shader-differences-on-ios
//ERROR: 0:51: 'mat3' : declaration must include a precision qualifier for type
//precision mediump float;

//https://gist.github.com/roxlu/5795504

#version 330

out vec4 FragColor;
uniform sampler2DRect SamplerY;
uniform vec2 textureDimensionY;

uniform mat3 colorConversionMatrix;
in vec2 texCoordVarying;

const vec3 R_cf = vec3(1.164383,  0.000000,  1.596027);
const vec3 G_cf = vec3(1.164383, -0.391762, -0.812968);
const vec3 B_cf = vec3(1.164383,  2.017232,  0.000000);
const vec3 offset = vec3(-0.0625, -0.5, -0.5);

void main()
{
    
    vec2 recTexCoordX = texCoordVarying * textureDimensionY;
    vec3 tc = texture(SamplerY, recTexCoordX).rgb;
    vec3 yuv = vec3(tc.g, tc.b, tc.r);
    yuv += offset;
    FragColor.r = dot(yuv, R_cf);
    FragColor.g = dot(yuv, G_cf);
    FragColor.b = dot(yuv, B_cf);
    FragColor.a = 1.0;
    
////    FragColor = rgba.bgra;
//    vec3 yuv = rgba.gbr;
//    vec3 rgb = yuv * colorConversionMatrix;
//    FragColor = vec4(rgb,1.0);
//    vec3 rgb = rgba.rgb;
//    vec3 rgb = rgba.rbg;
//    vec3 rgb = rgba.bgr;
//    vec3 rgb = rgba.brg;
//    vec3 rgb = rgba.gbr;
//    vec3 rgb = rgba.grb;
//    FragColor = vec4(rgb.g,rgb.b,rgb.r,1.0);
//    FragColor = vec4(rgb.g,rgb.r,rgb.b,1.0);
//    FragColor = vec4(rgb.b,rgb.r,rgb.g,1.0);
//    FragColor = vec4(rgb.b,rgb.g,rgb.r,1.0);
//    FragColor = vec4(rgb.r,rgb.g,rgb.b,1.0);
//    FragColor = vec4(rgb.r,rgb.b,rgb.g,1.0);
}
