//  FFmpegTutorial
//
//  Created by qianlongxu.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.


//https://stackoverflow.com/questions/8788049/shader-differences-on-ios
//ERROR: 0:51: 'mat3' : declaration must include a precision qualifier for type
//precision mediump float;

uniform sampler2DRect SamplerY;
uniform sampler2DRect SamplerUV;
uniform vec2 textureDimensionY;
uniform vec2 textureDimensionUV;

uniform mat3 colorConversionMatrix;
varying vec2 texCoordVarying;

void main()
{
    vec3 yuv;
    vec3 rgb;
    
    vec2 recTexCoordY = texCoordVarying * textureDimensionY;
    vec2 recTexCoordUV = texCoordVarying * textureDimensionUV;
    
    //使用 r,g,b 都可以，a不行！
    yuv.x = texture2DRect(SamplerY, recTexCoordY).r;
    //这里翻转 UV ！！
    yuv.zy = texture2DRect(SamplerUV, recTexCoordUV).rg - vec2(0.5, 0.5);
    rgb = colorConversionMatrix * yuv;
    
    gl_FragColor = vec4(rgb, 1);
}
