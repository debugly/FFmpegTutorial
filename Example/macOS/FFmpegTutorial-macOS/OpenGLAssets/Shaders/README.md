## OpenGL Shader

- macOS 不支持精度的设定，比如 mediump ；iOS 需要指定精度
- macOS 需要使用 sampler2DRect，并且还需要给出尺寸才行；iOS 相对简单，直接使用 sampler2D 即可

注：带有 v3 后缀的是 OpenGL 3 使用的 shader。


1、为什么使用 sampler2DRect 而不是 sampler2D ？
解码数据放在了 CVPixelBufferRef 结构体里面了，要想直接渲染，需要先转成 IOSurfaceRef 然后
借助 CGLTexImageIOSurface2D 实现纹理绑定。
而 CGLTexImageIOSurface2D 需要使用 sampler2DRect 采样器，

如果否则 creating IOSurface texture 失败

2、OpenGL定义的 glTexImage2D 也可以做纹理绑定，可以使用 sampler2D，但是为了能够复用一个 shader 程序，因此选择使用 sampler2DRect

3、采样器和纹理格式要对应，否则就会绿屏。
sampler2D 采样器对应的纹理是 GL_TEXTURE_2D ，而 sampler2DRect 对应的纹理是 GL_TEXTURE_RECTANGLE。

4、sampler2DRect 采样器的坐标不是[0,1]，而是纹理的原始尺寸 [w,h] ，如果坐标不对，很可能是黑屏，因为取不到相应的像素。
 
