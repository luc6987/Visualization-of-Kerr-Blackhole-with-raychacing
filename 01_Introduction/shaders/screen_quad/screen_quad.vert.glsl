#version 330 core

layout(location = 0) in vec3 position;


out vec2 uv;  

void main()
{
    uv = 0.5 * (position.xy + vec2(1.0)); // 把 [-1,1] 映射到 [0,1]
    gl_Position = vec4(position, 1.0);

}
