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

uniform sampler2DRect SamplerY;
uniform sampler2DRect SamplerU;
uniform sampler2DRect SamplerV;

uniform vec2 textureDimensionY;
uniform vec2 textureDimensionU;
uniform vec2 textureDimensionV;

uniform mat3 colorConversionMatrix;


void main()
{
    vec3 yuv;
    vec3 rgb;
    
    vec2 recTexCoord0 = texCoordVarying * textureDimensionY;
    vec2 recTexCoord1 = texCoordVarying * textureDimensionU;
    vec2 recTexCoord2 = texCoordVarying * textureDimensionV;
    
    yuv.x = texture(SamplerY, recTexCoord0).r;
    yuv.y = texture(SamplerU, recTexCoord1).r - 0.5;
    yuv.z = texture(SamplerV, recTexCoord2).r - 0.5;
    
    rgb = colorConversionMatrix * yuv;
    FragColor = vec4(rgb, 1);
}
