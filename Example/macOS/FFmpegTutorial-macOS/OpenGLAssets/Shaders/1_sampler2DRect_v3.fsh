//  FFmpegTutorial
//
//  Created by qianlongxu.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.


//https://people.freedesktop.org/~marcheu/extensions/APPLE/ycbcr_422.html
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
