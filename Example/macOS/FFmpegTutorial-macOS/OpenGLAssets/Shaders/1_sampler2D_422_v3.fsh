//  FFmpegTutorial
//
//  Created by qianlongxu.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.


// https://people.freedesktop.org/~marcheu/extensions/APPLE/ycbcr_422.html
//https://stackoverflow.com/questions/8788049/shader-differences-on-ios
//ERROR: 0:51: 'mat3' : declaration must include a precision qualifier for type
//precision mediump float;

//https://gist.github.com/roxlu/5795504

#version 330

out vec4 FragColor;
uniform sampler2D Sampler0;
uniform mat3 colorConversionMatrix;

in vec2 texCoordVarying;

const vec3 offset = vec3(-0.0625, -0.5, -0.5);

void main()
{
    vec3 tc = texture(Sampler0, texCoordVarying).rgb; //vyu
    vec3 yuv = vec3(tc.g, tc.b, tc.r);
    yuv += offset;
    vec3 rgb = colorConversionMatrix * yuv;
    FragColor = vec4(rgb, 1);
}
