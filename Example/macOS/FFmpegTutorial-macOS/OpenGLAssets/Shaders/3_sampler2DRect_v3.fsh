//  FFmpegTutorial
//
//  Created by qianlongxu.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.


//https://stackoverflow.com/questions/8788049/shader-differences-on-ios
//ERROR: 0:51: 'mat3' : declaration must include a precision qualifier for type
//precision mediump float;

#version 330

out vec4 FragColor;
in vec2 texCoordVarying;

uniform sampler2DRect Sampler0;
uniform sampler2DRect Sampler1;
uniform sampler2DRect Sampler2;

uniform vec2 textureDimension0;
uniform vec2 textureDimension1;
uniform vec2 textureDimension2;

uniform mat3 colorConversionMatrix;


void main()
{
    vec3 yuv;
    vec3 rgb;
    
    vec2 recTexCoord0 = texCoordVarying * textureDimension0;
    vec2 recTexCoord1 = texCoordVarying * textureDimension1;
    vec2 recTexCoord2 = texCoordVarying * textureDimension2;
    
    yuv.x = texture(Sampler0, recTexCoord0).r;
    yuv.y = texture(Sampler1, recTexCoord1).r - 0.5;
    yuv.z = texture(Sampler2, recTexCoord2).r - 0.5;
    
    rgb = colorConversionMatrix * yuv;
    FragColor = vec4(rgb, 1);
}
