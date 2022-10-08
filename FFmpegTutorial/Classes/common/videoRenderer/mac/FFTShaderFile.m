//
//  FFTShaderFile.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/10/6.
//

#import "FFTShaderFile.h"

#define ALine(x) @#x"\n"

@implementation FFTShaderFile

+ (NSString *)commonV3vsh
{
    NSString *vsh =
    ALine(#version 330)
    ALine(in vec2 position;)
    ALine(in vec2 texCoord;)
    ALine(out vec2 texCoordVarying;)
    
    ALine(void main(){)
        ALine(gl_Position = vec4(position,0.0,1.0);)
        ALine(texCoordVarying = texCoord;)
    ALine(});
    return vsh;
}

+ (NSString *)nv12RectV3fhs
{
    NSString *fsh =
    ALine(#version 330)
    ALine(out vec4 FragColor;)
    ALine(uniform sampler2DRect Sampler0;)
    ALine(uniform sampler2DRect Sampler1;)
    ALine(uniform vec2 textureDimension0;)
    ALine(uniform vec2 textureDimension1;)
    
    ALine(uniform mat3 colorConversionMatrix;)
    ALine(in vec2 texCoordVarying;)
    
    ALine(void main(){)
        ALine(vec3 yuv;)
        ALine(vec3 rgb;)
        ALine(vec2 recTexCoordY  = texCoordVarying * textureDimension0;)
        ALine(vec2 recTexCoordUV = texCoordVarying * textureDimension1;)
        //使用 r,g,b 都可以，a不行！
        ALine(yuv.x  = texture(Sampler0, recTexCoordY).r;)
        //使用 ra,ga,ba 都可以！
        ALine(yuv.yz = texture(Sampler1, recTexCoordUV).rg - vec2(0.5, 0.5);)
        ALine(rgb = colorConversionMatrix * yuv;)
        ALine(FragColor = vec4(rgb, 1);)
    ALine(});
    return fsh;
}

@end
