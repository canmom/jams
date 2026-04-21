#version 430 core

//hello fieldfx crew! thanks for listening to the talk today!

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

const float PI = radians(180.0);
  
void main(void) {
  vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
    uv -= 0.5;
    uv /= vec2(v2Resolution.y / v2Resolution.x, 1);
  
  float fft_time = texture(texFFTIntegrated,0.1).r;
  
  
  vec3 cam_pos = vec3(cos(fft_time),1.5*sin(fft_time),0.45+0.05*sin(texture(texFFTIntegrated,0.3).r));
  
  vec3 cam_dir = normalize(-cam_pos);
  vec3 cam_x = normalize(cross(vec3(0,0,1),cam_dir));
  vec3 cam_y = normalize(cross(cam_x,cam_dir));
  
  vec3 ray_dir = normalize(cam_dir + uv.x * cam_x - uv.y * cam_y);
  
  float dist = 1.0/0.0;
  vec3 ray_pos = cam_pos;
  bool hit_sphere = false;
  float hit_flower = 0.0;
  
  for (int i = 0; i < 20; i++) {
    dist = length(ray_pos)-0.5;
    if (dist < 0.001) {
      hit_sphere = true;
      break;
    } else {
      ray_pos += (dist * ray_dir);
      
    }
  }
  
  if (hit_sphere) {
    for (int i = 0; i < 200; i++) {
      float layer = floor(length(ray_pos)*10.0);
      float longitude = atan(ray_pos.y, ray_pos.x)+texture(texFFTIntegrated,layer/10.0).r;
      float latitude = atan(ray_pos.z, length(ray_pos.xy))/PI+0.5;
      if (latitude < (0.8-0.15*layer)+0.4*abs(fract((2.0+layer)*longitude/PI)-0.5)) {
        hit_flower = layer/10.0;
        break;
      }
      ray_pos += 0.005 * ray_dir;
    }
    
  }
  
  if (hit_flower>0.0) {
      out_color = vec4(mix(vec3(0.8,0.1,0.4)*0.6,vec3(1.0,0.3,1.0),hit_flower+1.5*ray_pos.z), 1.0);
  } else {
    out_color = vec4(vec3(0.02, 0.02, 0.04),1.0);
  }
  vec2 frame_uv = gl_FragCoord.xy/v2Resolution;
  for (int i = -1; i<2; i++) {
    for (int j = -1; j<2; j++) {
      out_color += texture(texPreviousFrame,gl_FragCoord.xy/v2Resolution-vec2(i,j)*0.004)/9.0 * 0.4;
    }
  }
  out_color = tanh(1.5*out_color);
}
