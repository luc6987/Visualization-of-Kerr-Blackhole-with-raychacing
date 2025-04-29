#version 330 core


in vec2 uv;// 传入的纹理坐标 
//the texture coordinates passed in
out vec4 frag_color;// 输出颜色
// output color

uniform float time;// 时间 
// time
uniform float fov_y;// 视场角
// the field of view
uniform float aspect_ratio;// 宽高比
// aspect ratio
uniform vec2 resolution;// 屏幕分辨率
// screen resolution
uniform int show_blackhole;

uniform int background_type;
uniform float background_scale;
uniform float background_distance;
uniform mat4 view;
uniform sampler2D star_map;         // 从 CPU 设置贴图
// texture from CPU
uniform int kerr; // 是否使用 Kerr 黑洞
uniform int display_accretion_disk;

const float PI = 3.14159265358979323846;
const float beta = 0.0f; // velocity of camera
const float G = 1.0;
const float M = 1.0;
const float c = 1.0;

const float a = 1.0f; // Kerr 黑洞的自旋参数
// Kerr black hole spin parameter
const float Rs = 1.0f; // 黑洞半径
// Schwarzschild radius
const int max_steps = 1000; // raytracing 步数
// raytracing steps
const float dt = 0.005;// 积分步长
// integration step


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
    // x,y,z -> rho, theta, phi
    float rho = sqrt((pos.x * pos.x) + (pos.y * pos.y) + (pos.z * pos.z));
    float theta = atan(pos.z, pos.x);
    float phi = asin(pos.y /rho);
    return vec3(rho, theta, phi);
}

vec3 toXYZ(vec3 sphericalCoord){
    float rho = sphericalCoord.x;
    float theta = sphericalCoord.y;
    float phi = sphericalCoord.z;

    float x = rho * cos(theta) * sin(phi);
    float y = rho * sin(theta) * sin(phi);
    float z = rho * cos(phi);

    return vec3(x, y, z);
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

float star_map_uv(vec2 uv) {
    // 使用伪随机数生成一个 repeatable 的纹理
    uv = floor(uv * 512.0) / 512.0;

    vec2 coord1 = uv;
    vec2 coord2 = uv * 4.0;

    float s1 = fract(sin(dot(coord1, vec2(12.9898, 78.233))) * 43758.5453);
    float s2 = fract(sin(dot(coord2, vec2(93.9898, 67.345))) * 15731.345);

    float star = step(0.996, s1) * s2;

    return star; // 单通道亮度，可扩展为 RGB 彩色星空
}

vec3 background_sky_sphere(vec3 x, vec3 direction) {
    float PI = 3.14159265358979323846;

    vec3 dir = normalize(direction); // 使用世界方向坐标
    float u = 0.5 + atan(dir.x, dir.y) / (2.0 * PI);
    float v = acos(-dir.z) / PI;
    vec2 uv = vec2(u, v) * background_scale;

    float star = star_map_uv(uv); // 用你之前写的那套伪随机生成器

    return vec3(star);
}



// vec3 background_sky_sphere(vec3 x, vec3 direction) {
//     vec3 local_dir = normalize(cam_orientation * direction); // 防止光线方向非单位向量
//     vec2 uv = sphericalUV(local_dir);
//     vec3 color = texture(star_map, uv).rgb;
//     color = pow(color, vec3(1.0 / 2.2)); // gamma correction
//     return color;
// }



vec3 background_plane(vec3 x, vec3 direction) {
    float d = background_distance;
    vec3 origin = x;
    vec3 dir = direction;
    if (dir.z >= 0.0) return vec3(0.0); // 朝前方不渲染背景

    float t = -(origin.z + d) / dir.z;
    vec3 hit = origin + t * dir;
    vec2 coord = hit.xy * background_scale;

    if (background_type == 0) {
        float checker = mod(floor(coord.x) + floor(coord.y), 2.0);
        float color = mix(0.2, 0.95, checker);
        return vec3(color);
    }
    else {
        return vec3(coord * 0.5, 0.5); // 伪渐变
    };
}

vec3 background_color(vec3 x, vec3 direction) {
    

    if (background_type==2)
        return background_sky_sphere(x, direction);
    else
        return background_plane(x, direction);
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
    density *= 1600.0;

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

    //vec4 dustColor = getBlackBodyColor(accretionTempMod *  redshift) * 0.5;

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
    float alpha = 0.9;

    if(show_blackhole == 0) {
        return background_color(pos, ray.direction); // 不渲染黑洞
    }

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
    vec3 bg = background_color(pos, dir);

    return accumulated_color.rgb + alpha * bg;
}


//----------------------------------------------------------
struct Geodesic {
    float r;
    float theta;
    float phi;
    float p_r;
    float p_theta;

    float b; // angular momentum p_phi
    float q; //carter constant p_theta^2-cos(theta)^2*(b^2/sin(theta)^2-a^2)

    int toInfinity;// is the geodesic escaping to infinity? 1: yes, 0: no
};
// Kerr black hole functions
// Kerr 黑洞函数
float rho2(float r, float theta) {
    return r*r + a*a*cos(theta)*cos(theta);
}

float rho(float r, float theta) {
    return sqrt(rho2(r, theta));
}

float Delta(float r) {
    return r*r - 2.0f*r + a*a;
}

float Sigma2(float r, float theta) {
    float a2=a*a;
    float r2=r*r;
    float rpa=r2 + a2;
    float sin=sin(theta);
    return rpa*rpa-a2*sin*sin*Delta(r);
}

float Sigma(float r, float theta) {
    return sqrt(Sigma2(r, theta));
}

float alpha(float r, float theta) {
    return rho(r, theta) *sqrt( Delta(r) )/ Sigma(r, theta);
}

float omega(float r, float theta) {
    return 2.0f * a * r /Sigma2(r, theta);
}

float omega_bar(float r, float theta) {
    return Sigma(r, theta)*sin(theta) / rho(r, theta);
}

float b0(float r){
    float r2=r*r;
    float a2=a*a;
    return -(r*r2-3*r2+a2*r+a2)/(a*(r-1));
}

float q0(float r){
    float r2=r*r;
    float a2=a*a;
    return -(r*r2*(r*r2-6*r2+9*r-4*a2))/(a2*(r-1)*(r-1));
}

float p(float r, float b){
    return r*r+a*a-a*b;
}

float R(float r, float theta,float b,float q) {
    float p=p(r,b);
    return p*p-Delta(r)*((b-a)*(b-a)+q);
}

float Theta(float r, float theta,float b,float q) {

    return q-cos(theta)*cos(theta)*(b*b/(sin(theta)*sin(theta))-a*a);
}

float Theta(float p_theta){
    return p_theta*p_theta;
}




//---------------------------------------------------------------------
// to see whether the geodesic is escaping to infinity

float signf(float x) {
    return (x > 0.0) ? 1.0 : ((x < 0.0) ? -1.0 : 0.0);
}

// Cardano’s method for solving depressed cubic: x^3 + a x + b = 0
float solve_cubic_real_root(float a, float b) {
    float D = 0.25 * b * b + (1.0 / 27.0) * a * a * a;

    if (D >= 0.0) {
        float sqrtD = sqrt(D);
        float u = signf(-0.5 * b + sqrtD) * pow(abs(-0.5 * b + sqrtD), 1.0 / 3.0);
        float v = signf(-0.5 * b - sqrtD) * pow(abs(-0.5 * b - sqrtD), 1.0 / 3.0);
        return u + v;
    } else {
        float r = sqrt(-a / 3.0);
        float phi = acos(-b / (2.0 * pow(-a / 3.0, 1.5)));
        return 2.0 * r * cos(phi / 3.0);
    }
}

// Main function to compute the largest real root of f(x) = x^4 + p x^2 + q x + r
float get_max_real_root(float p, float q, float r) {
    // Step 1: Solve resolvent cubic: y^3 + p y^2 + (p^2/4 - r) y - q^2/8 = 0
    float a = p;
    float b = (p * p) / 4.0 - r;
    float c = -q * q / 8.0;

    float y = solve_cubic_real_root(b - a * a / 3.0, 
                (2.0 * a * a * a - 9.0 * a * b + 27.0 * c) / 27.0); // depressed cubic

    y = y - a / 3.0; // undo the Tschirnhaus shift

    if (y < 0.0) return -1e10; // no real roots

    float R2 = y;
    float R = sqrt(R2);

    float D2 = -2.0 * y - p + 2.0 * q / R;
    float E2 = -2.0 * y - p - 2.0 * q / R;

    float roots[4];
    int count = 0;

    if (D2 >= 0.0) {
        float D = sqrt(D2);
        roots[count++] = (-R + D) * 0.5;
        roots[count++] = (-R - D) * 0.5;
    }

    if (E2 >= 0.0) {
        float E = sqrt(E2);
        roots[count++] = (R + E) * 0.5;
        roots[count++] = (R - E) * 0.5;
    }

    if (count == 0) return -1e10;

    float max_root = roots[0];
    for (int i = 1; i < count; ++i) {
        if (roots[i] > max_root) {
            max_root = roots[i];
        }
    }

    return max_root;
}

//----------------------------------------------------------



vec3 XYZtoFIDO_vector(vec3 cam_pos, vec3 cam_dir){
    // input: cam_pos in spherical coordinates
    //        cam_dir in XYZ
    // output: fido_dir in FIDO coordinates
    vec3 fido_dir;
    // convert cam_pos to spherical coordinates
    float theta = cam_pos.y;
    float phi   = cam_pos.z;

    vec3 e_r     = vec3(sin(theta)*cos(phi), cos(theta), sin(theta)*sin(phi));
    vec3 e_theta = vec3(cos(theta)*cos(phi), -sin(theta), cos(theta)*sin(phi));
    vec3 e_phi   = vec3(-sin(phi), 0.0, cos(phi));

    fido_dir.x = dot(cam_dir, e_r);
    fido_dir.y = dot(cam_dir, e_theta);
    fido_dir.z = dot(cam_dir, e_phi);
    // convert fido_dir to FIDO coordinates:
    fido_dir.x=fido_dir.x * (rho(cam_pos.x, cam_pos.y) / sqrt(Delta(cam_pos.x)));
    fido_dir.y=fido_dir.y * rho(cam_pos.x, cam_pos.y);
    fido_dir.z=fido_dir.z * (rho(cam_pos.x, cam_pos.y) / sqrt(Delta(cam_pos.x)));
    return fido_dir;
}

Geodesic init_geodesic(vec3 cam_pos, vec3 cam_dir, vec2 ray_dir_local_spherical,float beta){
    //input: cam_pos in XYZ
    //       cam_dir in XYZ
    //       ray_dir_local_spherical in camera coordinates
    //       beta: velocity of camera
    //ouput:the parameters of geodesic in BL coordinates

    // Step 1: convert cam_dir to FIDO coordinates
    cam_pos = toSpherical(cam_pos); // cam_pos in spherical coordinates
    vec3 B = normalize(XYZtoFIDO_vector(cam_pos, cam_dir)); //B:r,theta,phi

    // Step 2: compute Nx, Ny, Nz,the direction of the ray in the camera coodinates
    vec3 Ni=vec3(0.0);
    Ni.x = sin(ray_dir_local_spherical.x) * cos(ray_dir_local_spherical.y);
    Ni.y = sin(ray_dir_local_spherical.x) * sin(ray_dir_local_spherical.y);
    Ni.z = cos(ray_dir_local_spherical.x);

    // Step 3.1: compute n_F the direction of the ray in FIDO coordinates in cartesian bases
    vec3 nFi=vec3(0.0);

    float domme=(1.0f-beta*Ni.y);
    float nomm=-sqrt(1-beta*beta)/domme;
    nFi.x = nomm*Ni.x;
    nFi.y = (-Ni.y+beta)/domme;
    nFi.z = nomm*Ni.z;

    // Step 3.2: compute nFi_hat the direction of the ray in FIDO coordinates in spherical bases
    float kappa = sqrt(1-B.y*B.y);

    vec3 nFi_hat;//r,theta,phi
    nFi_hat.x = B.z*nFi.x / kappa 
                + B.x*nFi.y 
                + B.x*B.y*nFi.z/kappa;

    nFi_hat.y =     B.y*nFi.y 
                - kappa * nFi.z; 

    nFi_hat.z = - B.x*nFi.z / kappa 
                + B.z*nFi.y 
                + B.y*B.z*nFi.z/kappa;

    // Step 4: compute the canonical parameters of the geodesic: p_t = -1 by the convention and p_phi = b is conserved
    Geodesic g;
    g.r = cam_pos.x;
    g.theta = cam_pos.y;
    g.phi = cam_pos.z;

    float energy =  1.0f/(alpha(g.r, g.theta) 
    + omega(g.r, g.theta) * omega_bar(g.r, g.theta) * nFi_hat.z);


    g.p_r = energy * nFi_hat.x *  rho(g.r, g.theta)/sqrt(Delta(g.r));
    g.p_theta = energy * nFi_hat.y * rho(g.r, g.theta);
    g.b = energy * nFi_hat.z * omega_bar(g.r, g.theta) ;
    g.q = g.p_theta * g.p_theta +cos(g.theta)*cos(g.theta) * (g.b*g.b / (sin(g.theta)*sin(g.theta)) - a*a) ;

    // Step 5: to see if the geodesic is escaping to infinity
    bool v1, v2=false;

    float r1= 2*(1+cos(2*acos(-a)/3.0));
    float r2= 2*(1+cos(2*acos(a)/3.0)); 
    float b1= b0(r1);
    float b2= b0(r2);

    if(b1<g.b && g.b < b2){v1 = true;}

    if(g.q<q0(g.r)){v2 = true;}

    if(v1 && v2){
        if(g.p_r > 0.0f){
            g.toInfinity = 0;
        }else{
            g.toInfinity = 1;
        }
    }else{
        float C2 = a*a-g.b*g.b - g.q;
        float C1 = 2.0 * ((g.b - a) * (g.b - a) + g.q);
        float C0 = -a * a * g.q;
        float r_up = get_max_real_root(C2, C1, C0);
        if(g.r>=r_up){
            g.toInfinity = 1;
        }else{
            g.toInfinity = 0;
        }
    }

    return g;
}

//----------------------------------------------------------
// the funcionts to calculate RK4

float f_r(Geodesic g) {
    return Delta(g.r)*g.p_r/rho2(g.r,g.theta);
}

float f_theta(Geodesic g) {
    return g.p_theta/rho2(g.r,g.theta); 
}

float f_phi(Geodesic g) {
    return ((g.r*g.r+a*a-a*g.b)*a+Delta(g.r)*(g.b/(sin(g.theta)*sin(g.theta))-a))/(Delta(g.r)*rho2(g.r,g.theta)); 
}

float f_p_r(Geodesic g) {
    float Delta = Delta(g.r);
    float rho2 = rho2(g.r, g.theta);
    float R = R(g.r, g.theta, g.b, g.q);
    float p = p(g.r, g.b);
    float domme1=( -g.p_r * g.p_r*(2*g.r-2)+((p*g.r-(g.r-1)*((g.b-a)*(g.b-a)+g.q))*Delta-(g.r-1)*R)/(Delta*Delta))*rho2;
    float domme2=4*g.r*(-g.p_r*g.p_r*Delta+R/(2*Delta));
    return (domme1+domme2)/(4*rho2*rho2);// to verify
}

float f_p_theta(Geodesic g) {
    float Delta = Delta(g.r);
    float rho2 = rho2(g.r, g.theta);
    float R = R(g.r, g.theta, g.b, g.q);
    float domme = a*a*sin(2*g.theta)*(R/(2*Delta)-g.p_r*g.p_r*Delta);
    float nomme = 2*rho2*rho2;
    return domme/nomme;// to verify
}

Geodesic RK4_step(Geodesic g, float h) {
    // k1
    float k1_r = f_r(g);
    float k1_theta = f_theta(g);
    float k1_phi = f_phi(g);
    float k1_p_r = f_p_r(g);
    float k1_p_theta = f_p_theta(g);

    // k2
    Geodesic g2 = g;
    g2.r += 0.5 * h * k1_r;
    g2.theta += 0.5 * h * k1_theta;
    g2.phi += 0.5 * h * k1_phi;
    g2.p_r += 0.5 * h * k1_p_r;
    g2.p_theta += 0.5 * h * k1_p_theta;

    float k2_r = f_r(g2);
    float k2_theta = f_theta(g2);
    float k2_phi = f_phi(g2);
    float k2_p_r = f_p_r(g2);
    float k2_p_theta = f_p_theta(g2);

    // k3
    g2 = g;
    g2.r += 0.5 * h * k2_r;
    g2.theta += 0.5 * h * k2_theta;
    g2.phi += 0.5 * h * k2_phi;
    g2.p_r += 0.5 * h * k2_p_r;
    g2.p_theta += 0.5 * h * k2_p_theta;

    float k3_r = f_r(g2);
    float k3_theta = f_theta(g2);
    float k3_phi = f_phi(g2);
    float k3_p_r = f_p_r(g2);
    float k3_p_theta = f_p_theta(g2);

    // k4
    g2 = g;
    g2.r += h * k3_r;
    g2.theta += h * k3_theta;
    g2.phi += h * k3_phi;
    g2.p_r += h * k3_p_r;
    g2.p_theta += h * k3_p_theta;

    float k4_r = f_r(g2);
    float k4_theta = f_theta(g2);
    float k4_phi = f_phi(g2);
    float k4_p_r = f_p_r(g2);
    float k4_p_theta = f_p_theta(g2);

    // 更新值
    Geodesic g_new = g;
    g_new.r += (h / 6.0) * (k1_r + 2.0 * k2_r + 2.0 * k3_r + k4_r);
    g_new.theta += (h / 6.0) * (k1_theta + 2.0 * k2_theta + 2.0 * k3_theta + k4_theta);
    g_new.phi += (h / 6.0) * (k1_phi + 2.0 * k2_phi + 2.0 * k3_phi + k4_phi);
    g_new.p_r += (h / 6.0) * (k1_p_r + 2.0 * k2_p_r + 2.0 * k3_p_r + k4_p_r);
    g_new.p_theta += (h / 6.0) * (k1_p_theta + 2.0 * k2_p_theta + 2.0 * k3_p_theta + k4_p_theta);

    return g_new;
}

//----------------------------------------------------------

vec3 background_kerr_grid(float theta, float phi) {
    // 将 theta ∈ [0, π] 映射到 v ∈ [0,1]
    float v = theta / PI;

    // 将 phi ∈ [0, 2π] 映射到 u ∈ [0,1]
    float u = phi / (2.0 * PI);

    vec2 uv = vec2(u, v);

    float scale = background_scale*20; // 可调 uniform
    vec2 grid = floor(uv * scale);

    float checker = mod(grid.x + grid.y, 2.0);
    return vec3(checker);
}

vec3 raytrace_kerr(Geodesic g) {
    for (int i = 0; i < max_steps; ++i) {
        // 积分一步
        g = RK4_step(g, dt);
        }
    if (g.toInfinity == 1) {
        return background_kerr_grid(g.theta, g.phi);
    } else {
        return vec3(1.0); // 黑洞吞噬
    }
}

void main() {
    // the view matrix is defined by the camera position and orientation
    mat4 view_inv = inverse(view);
    vec3 cam_pos = view_inv[3].xyz;
    vec3 cam_right = normalize(view_inv[0].xyz);
    vec3 cam_up = normalize(view_inv[1].xyz);
    vec3 cam_forward = normalize(-view_inv[2].xyz);

    // 将纹理坐标转换为 NDC 坐标,d=1
    // supposing d=1 extract the direction of the ray
    vec2 ndc = uv * 2.0 - 1.0;
    float fov_rad = radians(fov_y);
    float tan_half_fov = tan(fov_rad / 2.0);
    float x = ndc.x * aspect_ratio * tan_half_fov;
    float y = ndc.y * tan_half_fov;

    // 构造世界空间中的光线方向
    vec3 ray_dir_world = normalize(x * cam_right +  y *cam_up + cam_forward);

    //In the raytracing, according to the paper of K. Thorne, the reference frame which is connected to the camera is difined as follow:
    //1. the camera is at the origin of the reference frame
    //2. the camera is looking at the positive y-axis
    //3. the x-axis is pointing to the right of the camera
    //4. the z-axis is pointing to the up of the camera
    //5. the direction of light is noted by two vairables:  theta_cs and phi_cs
    //6. theta_cs and phi_cs are defined as the spherical coordinates that takes z-axis as the polar axis and x-axis as the azimuthal axis

// 转到相机空间（Kip Thorne 定义的右-前-上坐标系）
    vec3 ray_dir_camera = mat3(view) * ray_dir_world;

// 转球坐标
    float theta = acos(ray_dir_camera.z); // z 是上，极角
    float phi = atan(ray_dir_camera.y, ray_dir_camera.x); // 方位角

    vec2 ray_dir_local_spherical = vec2(theta, phi);

    vec3 color;

    Ray ray;

        if (kerr == 1) {
            if (show_blackhole == 0) {
                color= background_kerr_grid(    acos(ray_dir_world.z),atan(ray_dir_world.y,ray_dir_world.x) );
            }else {
                Geodesic g = init_geodesic(cam_pos, cam_forward, ray_dir_local_spherical, beta);
                color = raytrace_kerr(g);
            }
        } else {

            ray.origin = cam_pos;
            ray.direction = ray_dir_world;
            color = raytrace(ray);
        }

  

    frag_color = vec4(color, 1.0);
}
