#version 330 core

in vec2 uv;// 传入的纹理坐标
out vec4 frag_color;// 输出颜色

uniform float time;// 时间
uniform float fov_y;// 视场角
uniform float aspect_ratio;// 宽高比
uniform vec2 resolution;// 屏幕分辨率
uniform int show_blackhole;// 是否显示黑洞
uniform vec3 cam_pos;
uniform mat3 cam_orientation;
uniform int background_type;
uniform float background_scale;
uniform float background_distance;
const float G = 1.0;
const float M = 1.0;
const float c = 1.0;

const float Rs = 1.0f; // 黑洞半径



struct Ray {
    vec3 origin; // 光线起点
    vec3 direction; // 光线方向
};

//	Simplex 3D Noise
//	by Ian McEwan, Ashima Arts
//  https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83
vec4 permute(vec4 x){ return mod(((x*34.0)+1.0)*x, 289.0); }
vec4 taylorInvSqrt(vec4 r){ return 1.79284291400159 - 0.85373472095314 * r; }

float snoise(vec3 v){
    const vec2  C = vec2(1.0/6.0, 1.0/3.0);
    const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);

    // First corner
    vec3 i  = floor(v + dot(v, C.yyy));
    vec3 x0 =   v - i + dot(i, C.xxx);

    // Other corners
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);

    //  x0 = x0 - 0. + 0.0 * C
    vec3 x1 = x0 - i1 + 1.0 * C.xxx;
    vec3 x2 = x0 - i2 + 2.0 * C.xxx;
    vec3 x3 = x0 - 1. + 3.0 * C.xxx;

    // Permutations
    i = mod(i, 289.0);
    vec4 p = permute(permute(permute(
    i.z + vec4(0.0, i1.z, i2.z, 1.0))
    + i.y + vec4(0.0, i1.y, i2.y, 1.0))
    + i.x + vec4(0.0, i1.x, i2.x, 1.0));

    // Gradients
    // ( N*N points uniformly over a square, mapped onto an octahedron.)
    float n_ = 1.0/7.0;// N=7
    vec3  ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49.0 * floor(p * ns.z *ns.z);//  mod(p,N*N)

    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);// mod(j,N)

    vec4 x = x_ *ns.x + ns.yyyy;
    vec4 y = y_ *ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);

    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);

    vec4 s0 = floor(b0)*2.0 + 1.0;
    vec4 s1 = floor(b1)*2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww;

    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);

    //Normalise gradients
    vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    // Mix final noise value
    vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m*m, vec4(dot(p0, x0), dot(p1, x1),
    dot(p2, x2), dot(p3, x3)));
}

vec3 toSpherical(vec3 pos){
    float rho = sqrt((pos.x * pos.x) + (pos.y * pos.y) + (pos.z * pos.z));
    float theta = atan(pos.z, pos.x);
    float phi = asin(pos.y /rho);
    return vec3(rho, theta, phi);
}

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
    float d = background_distance;
    vec3 dir = normalize(x - origin);
    if (dir.z >= 0.0) return vec3(0.0);

    float t = -(origin.z + d) / dir.z;
    vec3 hit = origin + t * dir;

    vec2 coord = hit.xy * background_scale;

    if (background_type == 0) {
        float checker = mod(floor(coord.x) + floor(coord.y), 2.0);
        float color = mix(0.2, 0.95, checker);
        return vec3(color);
    }
    else if (background_type == 1) {
        return vec3(coord * 0.0, 0.5); // 伪渐变
    }
    else {
        return vec3(fract(sin(dot(coord, vec2(12.9898,78.233))) * 43758.5453)); // 伪星空
    }
}


void diskRender(vec3 pos, inout vec4 color, inout float alpha, vec3 viewDir){
    float diskHeight = 0.3;
float diskDensityV = 1.0;
float diskDensityH = 2.0;
float diskNoiseScale = 1.0;
float diskSpeed = 0.5;
int diskNoiseLOD = 6;


    float innerRadius = 3.0; // inner radius of the disk
    float outerRadius = 9.0; // outer radius of the disk

    // disk density
    float density = max(0.0, 1.0 - length(pos / vec3(outerRadius, diskHeight, outerRadius)));

    // if disk density is too low, return
    if (density < 0.001){
        return;
    }

    // vertical density with a linear falloff
    density *= pow(1.0 - abs(pos.y) / diskHeight, diskDensityV);

    // 让密度在接近 innerRadius 时平滑降为零，模拟盘的内部边缘不会太突兀。
    density *= smoothstep(innerRadius, innerRadius * 1.1, length(pos));
    
    // if disk density is too low, return   
    if (density < 0.001){
        return;
    }

    // spherical coordinates
    vec3 sphericalCoord =  toSpherical(pos);

    sphericalCoord.y *= 2.0;
    sphericalCoord.z *= 4.0;

    density *= 1.0 / pow(sphericalCoord.x, diskDensityH);
    density *= 16000.0;

    float noise = 1.0;
    for (int i = 0; i < diskNoiseLOD; ++i){
        noise *= 0.5 * snoise(sphericalCoord * pow(i, 2) * diskNoiseScale) + 0.5;
        if (i % 2 == 0) {
            sphericalCoord.y -= time * diskSpeed;
        } else {
            sphericalCoord.y += time * diskSpeed;
        }
    }

    // float redshift = calculateRedShift(pos);
    // float doppler = calculateDopplerEffect(pos, viewDir);

    // float accretionTempMod = accretionTemp;

    // if (realisticTemperature)
    //     accretionTempMod = calculateRealisticTemperature(pos, accretionTempMod);

    // if(dopplerShift)
    //     accretionTempMod /= doppler;

    // if (gravitationalRedShift)
    //     accretionTempMod /= redshift;

    // vec4 dustColor = getBlackBodyColor(accretionTempMod *  redshift) * 0.5;

    color += density * alpha * abs(noise);// * dustColor

    // if (gravitationalRedShift)
    //     color /= redshift;

    // if (beaming)
    //     color /= doppler * doppler * doppler;
}

vec3 raytrace(Ray ray) {
    const int max_steps = 512;
    const float dt = 0.05;
    const float blackhole_radius = Rs;

    vec3 pos = ray.origin;
    vec3 dir = ray.direction;

    vec3 h = cross(pos, dir);
    float h2 = dot(h, h);

    vec4 accumulated_color = vec4(0.0); // 用 vec4 便于 alpha 衰减混合
    float alpha = 1.0;

    for (int i = 0; i < max_steps; ++i) {
        // disk 渲染（无论当前位置是否接近黑洞）
        // 积分一步
        rk4(pos,  dir,h2, dt);
        
        
        if (length(pos) < blackhole_radius) {
        return accumulated_color.rgb; // 完全被吸收，事件视界内不可逃逸
         }

        diskRender(pos, accumulated_color, alpha, dir);
        
    }

    // 添加背景（天空球/星空/渐变）
    vec3 bg = background_color(pos, ray.origin);

    return accumulated_color.rgb + alpha * bg;
}






void main() {
    vec2 ndc = uv * 2.0 - 1.0;
    float fov_rad = radians(fov_y);
    float tan_half_fov = tan(fov_rad / 2.0);

    float x = ndc.x * aspect_ratio * tan_half_fov;
    float y = ndc.y * tan_half_fov;
    
    // 构造相机本地空间中的方向
    vec3 dir_local = normalize(vec3(x, y, -1.0));

    // 转换到世界空间方向
    vec3 ray_dir = normalize(cam_orientation * dir_local);

    Ray ray;
    ray.origin = cam_pos;
    ray.direction = ray_dir;


    vec3 color = raytrace(ray);
    frag_color = vec4(color, 1.0);
}
