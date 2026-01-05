#version 420 core

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

void main(void)
{
  vec2 uv = 0.06*vec2(gl_FragCoord.x - v2Resolution.x * 0.5, gl_FragCoord.y - v2Resolution.y * 0.5) / v2Resolution.y;

  ivec2 pos = ivec2(5,5);
  float v = 0;
  if (ivec2(gl_FragCoord.xy) == ivec2(5,5)) {
    for (float f = 0.0; f < 1.0; f += 1.0/1024.0)
    {
      v += texture(texFFTSmoothed, f).r;
    }
    //v += fGlobalTime;
    imageStore(computeTex[1], pos, uvec4(v * (0xFFFFFFFFu>>10)));
    imageStore(computeTex[1], ivec2(6,5), uvec4(texture(texFFTSmoothed,0.1).r*0xFFFFFFFFu));
  }
  float sum = float(imageLoad(computeTexBack[1], pos)).r/float(0xFFFFFFFFu);
  float single = float(imageLoad(computeTexBack[1],ivec2(6,5))).r/float(0xFFFFFFFFu);
  
  out_color = vec4(step(length(uv), single),step(length(uv), sum),0.0,1.0);
}