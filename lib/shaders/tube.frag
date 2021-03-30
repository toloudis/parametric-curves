// #extension GL_OES_standard_derivatives : enable
precision highp float;

in vec3 vNormal;
in vec2 vUv;
in vec3 vViewPosition;

uniform vec3 color;

#pragma glslify: faceNormal = require('glsl-face-normal');

out vec4 fragmentColor;
void main () {
  // handle flat and smooth normals
  vec3 normal = vNormal;
  #ifdef FLAT_SHADED
    normal = faceNormal(vViewPosition);
  #endif

  // Z-normal "fake" shading
  float diffuse = normal.z * 0.5 + 0.5;

  // add some "rim lighting"
  vec3 V = normalize(vViewPosition);
  float vDotN = 1.0 - max(dot(V, normal), 0.0);
  float rim = smoothstep(0.5, 1.0, vDotN);
  diffuse += rim * 2.0;

  //float distFromCenter = clamp(length(vViewPosition) / 5.0, 0.0, 1.0);
  
  // final color
  //fragmentColor = vec4(diffuse * color, 1.0);
  fragmentColor = vec4(0.5*(normal+1.0), 1.0);
}
