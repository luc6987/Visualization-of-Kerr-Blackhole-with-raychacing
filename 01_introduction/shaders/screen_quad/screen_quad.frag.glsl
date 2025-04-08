#version 330 core

in vec2 uv;// 传入的纹理坐标
out vec4 frag_color;// 输出颜色

uniform float time;// 时间
uniform float fov_y;// 视场角
uniform float aspect_ratio;// 宽高比
uniform vec2 resolution;// 屏幕分辨率
uniform int show_blackhole;// 是否显示黑洞

const float Rs = 0.3f; // 黑洞半径
const float d = 100.0f; // 背景平面在相机前 z = -d



struct Ray {
    vec3 origin; // 光线起点
    vec3 direction; // 光线方向
};

vec3 acceleration(float h2, vec3 pos) {
    float r2 = dot(pos, pos);
    float r5 = pow(r2, 2.5);
    return -1.5 * h2 * pos / r5;
}


void rk4(inout vec3 x, inout vec3 v, float h2, float dt) {
    vec3 k1_v = acceleration(h2, x);
    vec3 k1_x = v;

    vec3 k2_v = acceleration(h2, x + 0.5*dt*k1_x);
    vec3 k2_x = v + 0.5*dt*k1_v;

    vec3 k3_v = acceleration(h2, x + 0.5*dt*k2_x);
    vec3 k3_x = v + 0.5*dt*k2_v;

    vec3 k4_v = acceleration(h2, x + dt*k3_x);
    vec3 k4_x = v + dt*k3_v;

    x += dt * (k1_x + 2.0*k2_x + 2.0*k3_x + k4_x) / 6.0;
    v += dt * (k1_v + 2.0*k2_v + 2.0*k3_v + k4_v) / 6.0;
}

vec3 background_color(vec3 x, vec3 origin) {
    vec3 dir = normalize(x - origin);

    // 如果光线最终没有朝向背景平面，就返回黑色（逃逸了）
    if (dir.z >= 0.0)
        return vec3(0.0);

    float t = -(origin.z + d) / dir.z; // 求交点：z = -d
    vec3 hit = origin + t * dir;

    // 映射到棋盘格纹理
    float scale = 0.1; // 越大格子越小
    vec2 coord = hit.xy * scale;

    float checker = mod(floor(coord.x) + floor(coord.y), 2.0);
    float color = mix(0.2, 0.95, checker);

    return vec3(color);
}




vec3 raytrace(Ray ray) {

    if (show_blackhole==0) {
    vec3 x_far = ray.origin + ray.direction * 100.0;
    return background_color(x_far, ray.origin);
    }

    float t = 0.0;
    float dt = 0.01;
    int max_steps = 256;

    vec3 x = ray.origin;
    vec3 v = ray.direction;

    float h2 = length(cross(x, v));
    h2 *= h2;

    for (int i = 0; i < max_steps; ++i) {
        float r = length(x);
        if (r < Rs)
            return vec3(0.0); // 吸收进黑洞
        rk4(x, v, h2, dt);
        t += dt;
    }

    return background_color(x,ray.origin); // 用 x 最终方向映射背景
}


void main() {
    vec2 ndc = uv * 2.0 - 1.0;
    float fov_rad = radians(fov_y);
    float tan_half_fov = tan(fov_rad / 2.0);

    float x = ndc.x * aspect_ratio * tan_half_fov;
    float y = ndc.y * tan_half_fov;
    vec3 ray_dir = normalize(vec3(x, y, -1.0));

    Ray ray;
    ray.origin = vec3(0.0, 0.0, 2.0);
    ray.direction = ray_dir;

    vec3 color = raytrace(ray);
    frag_color = vec4(color, 1.0);
}
