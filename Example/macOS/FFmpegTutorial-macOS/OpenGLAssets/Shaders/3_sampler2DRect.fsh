//  FFmpegTutorial
//
//  Created by qianlongxu.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.


//https://stackoverflow.com/questions/8788049/shader-differences-on-ios
//ERROR: 0:51: 'mat3' : declaration must include a precision qualifier for type
//precision mediump float;

uniform sampler2DRect Sampler0;
uniform sampler2DRect Sampler1;
uniform sampler2DRect Sampler2;

uniform vec2 textureDimension0;
uniform vec2 textureDimension1;
uniform vec2 textureDimension2;

uniform mat3 colorConversionMatrix;
varying vec2 texCoordVarying;

void main()
{
    vec3 yuv;
    vec3 rgb;
    
    vec2 recTexCoordY = texCoordVarying * textureDimension0;
    vec2 recTexCoordU = texCoordVarying * textureDimension1;
    vec2 recTexCoordV = texCoordVarying * textureDimension2;
    
    yuv.x = texture2DRect(Sampler0, recTexCoordY).r;
    yuv.y = texture2DRect(Sampler1, recTexCoordU).r - 0.5;
    yuv.z = texture2DRect(Sampler2, recTexCoordV).r - 0.5;
    
    rgb = colorConversionMatrix * yuv;
    
    gl_FragColor = vec4(rgb, 1);
}
