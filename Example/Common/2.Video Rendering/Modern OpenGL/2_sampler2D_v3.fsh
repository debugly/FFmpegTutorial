//  FFmpegTutorial
//
//  Created by qianlongxu.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.


//https://stackoverflow.com/questions/8788049/shader-differences-on-ios
//ERROR: 0:51: 'mat3' : declaration must include a precision qualifier for type
//precision mediump float;

#version 330

out vec4 FragColor;
uniform sampler2D Sampler0;
uniform sampler2D Sampler1;

uniform mat3 colorConversionMatrix;
in vec2 texCoordVarying;

void main()
{
    vec3 yuv;
    vec3 rgb;
    
    //使用 r,g,b 都可以，a不行！
    yuv.x  = texture(Sampler0, texCoordVarying).r;
    //使用 ra,ga,ba 都可以！
    yuv.yz = texture(Sampler1, texCoordVarying).rg - vec2(0.5, 0.5);
    
    rgb = colorConversionMatrix * yuv;
    FragColor = vec4(rgb, 1);
}
