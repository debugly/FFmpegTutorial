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

uniform sampler2D Sampler0;
uniform sampler2D Sampler1;
uniform sampler2D Sampler2;

uniform mat3 colorConversionMatrix;

void main()
{
    vec3 yuv;
    vec3 rgb;
    
    yuv.x = texture(Sampler0, texCoordVarying).r;
    yuv.y = texture(Sampler1, texCoordVarying).r - 0.5;
    yuv.z = texture(Sampler2, texCoordVarying).r - 0.5;
    
    rgb = colorConversionMatrix * yuv;
    FragColor = vec4(rgb, 1);
}
