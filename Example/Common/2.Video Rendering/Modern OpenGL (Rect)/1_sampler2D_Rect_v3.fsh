//  FFmpegTutorial
//
//  Created by qianlongxu.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.


// https://people.freedesktop.org/~marcheu/extensions/APPLE/ycbcr_422.html
//https://stackoverflow.com/questions/8788049/shader-differences-on-ios
//ERROR: 0:51: 'mat3' : declaration must include a precision qualifier for type
//precision mediump float;

#version 330

out vec4 FragColor;
uniform sampler2DRect Sampler0;
uniform vec2 textureDimension0;
in vec2 texCoordVarying;

void main()
{
    vec2 recTexCoordY = texCoordVarying * textureDimension0;
    vec3 rgb = texture(Sampler0, recTexCoordY).rgb;
    FragColor = vec4(rgb, 1);
}
