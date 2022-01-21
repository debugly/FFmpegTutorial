//  FFmpegTutorial
//
//  Created by qianlongxu.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.


#version 330

in vec2 position;
in vec2 texCoord;

out vec2 texCoordVarying;

void main()
{
    gl_Position = vec4(position,0.0,1.0);
    texCoordVarying = texCoord;
}
