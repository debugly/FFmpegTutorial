//  FFmpegTutorial
//
//  Created by qianlongxu.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.


//https://stackoverflow.com/questions/8788049/shader-differences-on-ios
//ERROR: 0:51: 'mat3' : declaration must include a precision qualifier for type
//precision mediump float;

uniform sampler2D Sampler0;
uniform sampler2D Sampler1;

uniform mat3 colorConversionMatrix;
varying vec2 texCoordVarying;

void main()
{
    vec3 yuv;
    vec3 rgb;
    
    yuv.x  = texture2D(Sampler0, texCoordVarying).r;
    //因为是NV21，因此 r 是 v，a 是 u
    yuv.yz = texture2D(Sampler1, texCoordVarying).ar - vec2(0.5, 0.5);
    rgb = colorConversionMatrix * yuv;
    
    gl_FragColor = vec4(rgb, 1);
}
