## OpenGL Shader

- macOS 不支持精度的设定，比如 mediump ；iOS 需要指定精度
- macOS 需要使用 sampler2DRect，并且还需要给出尺寸才行；iOS 相对简单，直接使用 sampler2D 即可

注：带有 v3 后缀的是 OpenGL 3 使用的 shader。