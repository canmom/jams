#version 430 core

//greets to raccoonviolet weatherman, jtruk, marex, aldroid and littletheremin!
//today we grow life on a donut...

uniform float fGlobalTime; // in seconds
uniform vec2 v2Resolution; // viewport resolution (in pixels)
uniform float fFrameTime; // duration of the last frame, in seconds

uniform sampler1D texFFT; // towards 0.0 is bass / lower freq, towards 1.0 is higher / treble freq
uniform sampler1D texFFTSmoothed; // this one has longer falloff and less harsh transients
uniform sampler1D texFFTIntegrated; // this is continually increasing
uniform sampler2D texPreviousFrame; // screenshot of the previous frame
uniform sampler2D texChecker;
uniform sampler2D texNoise;
uniform sampler2D texTex1;
uniform sampler2D texTex2;
uniform sampler2D texTex3;
uniform sampler2D texTex4;

layout(r32ui) uniform coherent uimage2D[3] computeTex;
layout(r32ui) uniform coherent uimage2D[3] computeTexBack;

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

uint life(ivec2 UV, int forcing) {
  ivec2 res = imageSize(computeTex[0]);
  int left = (UV.x + res.x - 1) % res.x;
  int right = (UV.x + res.x + 1) % res.x;
  int up = (UV.y + res.y + 1) % res.y;
  int down = (UV.y + res.y - 1) % res.y;
  uint current = + imageLoad(computeTexBack[0],UV).x;
  uint living_neighbours = imageLoad(computeTexBack[0],ivec2(left, up)).x
  + imageLoad(computeTexBack[0],ivec2(UV.x, up)).x
  + imageLoad(computeTexBack[0],ivec2(right, up)).x
  + imageLoad(computeTexBack[0],ivec2(left, UV.y)).x
  + imageLoad(computeTexBack[0],ivec2(right,UV.y)).x
  + imageLoad(computeTexBack[0],ivec2(left,down)).x
  + imageLoad(computeTexBack[0],ivec2(UV.x,down)).x
  + imageLoad(computeTexBack[0],ivec2(right,down)).x
  + current;
  
  if (forcing > 0) {
    imageStore(computeTex[0],UV,uvec4(1));
    return current;
  } else if (forcing < 0) {
    imageStore(computeTex[0],UV,uvec4(0));
    return current;
  } else if (living_neighbours == 3) {
    imageStore(computeTex[0],UV,uvec4(1));
    return 1;
  } else if (living_neighbours == 4) {
    imageStore(computeTex[0],UV,uvec4(current));
    return current;    
  } else {
    imageStore(computeTex[0],UV,uvec4(0));
    return 0;
  }
}

const uint MAX_STEPS = 20;
const float PI = 3.14159265358;

float sample_ground_plane(vec3 camera_pos, vec3 camera_dir, vec2 uv, float fov_factor, float tex_scale) {
  vec3 camera_x = normalize(cross(camera_dir,vec3(0,0,1)));
  vec3 camera_y = normalize(cross(camera_x, camera_dir));
  vec3 ray = normalize((uv.x * camera_x + uv.y * camera_y) * fov_factor + camera_dir);
  if (ray.z >= 0) {
    return 0.0;
  } else {
    

    vec2 ground_position = tex_scale*camera_pos.z*ray.xy/ray.z + camera_pos.xy;
    ivec2 ground_uv = ivec2(mod(ground_position,v2Resolution));
    uint life_cell = imageLoad(computeTexBack[0],ground_uv).r;
    
    if (life_cell == 1) {
      return life_cell;
    } else {
      vec2 step_v = -0.3*ray.xy*tex_scale;
      
      //now we raymarch into the Game of Life plane
      for(int i = 0; i < MAX_STEPS; i++) {
        ground_position += step_v;
        ivec2 ground_uv = ivec2(mod(ground_position,v2Resolution));
        uint life_cell = imageLoad(computeTexBack[0],ground_uv).r;
        if (life_cell == 1) {
          return 0.2;
        }
      }
    }
  }
}

float sdf_torus(vec3 p, vec2 radii) {
  vec2 q = vec2(length(p.xy)-radii.x, mod(p.z + atan(p.y, p.x),2.0*PI)-PI);
  return length(q)-radii.y;
}

vec3 calcNormal( in vec3 pos, vec2 radii )
{
    vec2 e = vec2(1.0,-1.0)*0.5773;
    const float eps = 0.0005;
    return normalize(
            e.xyy*sdf_torus( pos + e.xyy*eps, radii ) + 
					  e.yyx*sdf_torus( pos + e.yyx*eps, radii ) + 
					  e.yxy*sdf_torus( pos + e.yxy*eps, radii ) + 
					  e.xxx*sdf_torus( pos + e.xxx*eps, radii ) );
}

vec4 sample_torus(vec3 camera_pos, vec3 camera_dir, vec2 uv, float fov_factor, float torus_radius) {
  vec3 camera_x = normalize(cross(camera_dir,vec3(0,0,1)));
  vec3 camera_y = normalize(cross(camera_x, camera_dir));
  vec3 ray = normalize((uv.x * camera_x + uv.y * camera_y) * fov_factor + camera_dir);
  //intersecting a ray with a torus requires solving a quartic
  //that doesn't sound fun so let's just raymarch a torus
  float b = 2.0*dot(camera_pos, ray);
  float c = dot(camera_pos, camera_pos - 8.0);
  float discriminant = b*b - 4*c;
  vec2 radii = vec2(4.0, 1.0+8.0*torus_radius);
  vec3 hit_pos = camera_pos;
    
    for (int i = 0; i < 40; ++i) {
      float d = sdf_torus(hit_pos, radii);
      if (d < 0.1) {
        float u = 0.5+0.5*atan(hit_pos.x, hit_pos.y)/PI;
        float o = length(hit_pos.xy) - 4.0;
        float v = 0.5+0.5*atan(o, mod(hit_pos.z+atan(hit_pos.y, hit_pos.x),2*PI)-PI)/PI;
        //now the cool part
        ivec2 life_uv = ivec2(vec2(u,v)*v2Resolution);
        vec3 normal = calcNormal(hit_pos, radii);
        return vec4(float(imageLoad(computeTexBack[0],life_uv).r), normal);
        //return vec4(v,normal);
        
      } else {
        hit_pos += d * ray;
      }
    }
    return vec4(0.0);
}

const int LOCK_INTERVAL = 60;

void set_lock(uint prev_lock) {
  if (ivec2(gl_FragCoord.xy) == ivec2(5, 5)) {
    
    if (prev_lock < LOCK_INTERVAL) {
      imageStore(computeTex[1],ivec2(1,1), uvec4(prev_lock));
    } else {
      imageStore(computeTex[1],ivec2(1,1),uvec4(0));
    }
  }
}

uint get_lock() {
  return imageLoad(computeTexBack[1],ivec2(1,1)).r;
}

const int[25] glider = { -1,-1,-1,-1,-1,
                         -1,-1,-1, 1,-1,
                         -1, 1,-1, 1,-1,
                         -1,-1, 1, 1,-1,
                         -1,-1,-1,-1,-1};

int is_glider(ivec2 offset) {
  if (offset.x >= 0 && offset.x < 5 && offset.y >= 0 && offset.y < 5) {
    return glider[offset.y * 5 + offset.x];
  } else {
    return 0;
  }
}

void main(void)
{ 
  float fft = texture(texFFTSmoothed, 0.05).x;
  float fftTime = texture(texFFTIntegrated, 0.1).x;
  vec2 offset = vec2(texture(texFFTIntegrated,0.3).x,texture(texFFTIntegrated,0.15).x);
  float noise = 120.0*texture(texNoise, gl_FragCoord.xy / v2Resolution + offset).x*fft * texture(texNoise, 20.0*gl_FragCoord.xy / v2Resolution).x;
  
  int noise_forcing = int(step(0.35,noise))-int(step(noise,0.04));
  //int noise_forcing = 0;
  
  vec2 uv = 2.0*gl_FragCoord.xy/v2Resolution.y - vec2(v2Resolution.x/v2Resolution.y,1.0);

  bool do_life = true;
  ivec2 UV = ivec2(gl_FragCoord.xy);
  
  float fftBin = float(UV.x/95)/20.0;
  float spect = texture(texFFTSmoothed,fftBin).x;

  uint l;
  if (do_life) {
    uint lock = get_lock();
    set_lock(lock+1);
    
    int forcing = 0;
    
    ivec2 res = ivec2(v2Resolution);
    UV.x = UV.x % 95;
    
    UV.x = abs(50+ int(spect*50) - UV.x) - 10;
    UV.y = abs(UV.y - int(spect*500) - res.y/2);
    //UV.y = UV.y - 100;
    
    
    if (lock == 0) {
      forcing = is_glider(UV) * int(spect>0.05);
    }
    
    l = life(ivec2(gl_FragCoord.xy), forcing);
    
  } else {
    uint lock = get_lock();
    set_lock(lock);
    l = imageLoad(computeTexBack[0],ivec2(gl_FragCoord.xy)).x;
    imageStore(computeTex[0],ivec2(gl_FragCoord.xy),ivec4(l));
  }

  
  float camera_rotation_time = 0.05*fGlobalTime;
  vec2 camera_rotation = vec2(cos(camera_rotation_time),sin(camera_rotation_time));
  
  float cost = cos(fftTime);
  float sint = sin(fftTime);
  
  //float ground_sample = sample_ground_plane(vec3(25.0 * camera_rotation, 40.0), normalize(vec3(-camera_rotation, -0.2)), uv, 0.2, 0.5);
  vec4 torus_sample = sample_torus(vec3(-30.0*cost, -30.0*sint, 20.0*cos(0.5*fftTime)+fftTime), normalize(vec3(1.2*cost, 1.2*sint, -0.8*cos(0.5*fftTime))), uv, 0.2, fft);
  
  vec3 light_direction = normalize(vec3(-0.2, -0.6, 0.5));
  
  float lighting = clamp(dot(torus_sample.yzw, light_direction), 0.0, 1.0) + 0.02;
  
  float torus = dot(torus_sample.yzw,torus_sample.yzw);
  
  float bg = 1.0-torus;
  
  
  //out_color = vec4(spect>0.05);
  //out_color = vec4(test_norm,test2_norm,test3_norm, 1.0);
  out_color = vec4(atan((vec3(0.01,0.01,0.01)+vec3(0.03,0.00,0.03)*lighting)*torus +0.1*bg*l+5.0*torus_sample.x*vec3(0.6,0.2,0.6)*lighting),1.0);
  //out_color = vec4(is_glider((ivec2(gl_FragCoord)-ivec2(800,800))));
  //out_color = vec4(noise_add, noise_subtract, 0, 1.0);
}