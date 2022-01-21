//  FFmpegTutorial
//
//  Created by qianlongxu.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.


//https://stackoverflow.com/questions/8788049/shader-differences-on-ios
//ERROR: 0:51: 'mat3' : declaration must include a precision qualifier for type
//precision mediump float;

uniform sampler2DRect SamplerY;
uniform sampler2DRect SamplerU;
uniform sampler2DRect SamplerV;

uniform vec2 textureDimensionY;
uniform vec2 textureDimensionU;
uniform vec2 textureDimensionV;

uniform mat3 colorConversionMatrix;
varying vec2 texCoordVarying;

void main()
{
    vec3 yuv;
    vec3 rgb;
    
    vec2 recTexCoordY = texCoordVarying * textureDimensionY;
    vec2 recTexCoordU = texCoordVarying * textureDimensionU;
    vec2 recTexCoordV = texCoordVarying * textureDimensionV;
    
    yuv.x = texture2DRect(SamplerY, recTexCoordY).r;
    yuv.y = texture2DRect(SamplerU, recTexCoordU).r - 0.5;
    yuv.z = texture2DRect(SamplerV, recTexCoordV).r - 0.5;
    
    rgb = colorConversionMatrix * yuv;
    
    gl_FragColor = vec4(rgb, 1);
}
