#version 330 core

layout(location = 0) in vec3 position;

// Uniform variables expected to receive from the C++ program
uniform mat4 model; // Model affine transform matrix associated to the current shape
uniform mat4 view;  // View matrix (rigid transform) of the camera
uniform mat4 projection; // Projection (perspective or orthogonal) matrix of the camera

out vec2 uv;  

void main()
{
    uv = 0.5 * (position.xy + vec2(1.0)); // transforming xy in [-1,1] to uv in [0,1]
    gl_Position = vec4(position, 1.0);

}
