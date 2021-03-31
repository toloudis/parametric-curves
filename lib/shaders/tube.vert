// attributes of our mesh
in float position;
in float angle;
in vec2 uv;

// built-in uniforms from ThreeJS camera and Object3D
uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;
uniform mat3 normalMatrix;

// custom uniforms to build up our tubes
uniform float thickness;
uniform float time;
uniform float index;
uniform float radialSegments;

uniform sampler2D curveData;

// pass a few things along to the vertex shader
out vec2 vUv;
out vec3 vViewPosition;
out vec3 vNormal;

// Import a couple utilities
#pragma glslify: PI = require('glsl-pi');
#pragma glslify: ease = require('glsl-easings/exponential-in-out');

// Some constants for the robust version
#ifdef ROBUST
  const float MAX_NUMBER = 1.79769313e+308;
  const float EPSILON = 1.19209290e-7;
#endif

// Angles to spherical coordinates
vec3 spherical (float r, float phi, float theta) {
  return r * vec3(
    cos(phi) * cos(theta),
    cos(phi) * sin(theta),
    sin(phi)
  );
}

vec4 initCubicPolynomial(float x0, float x1, float t0, float t1) {
  return vec4(x0, t0, - 3.0 * x0 + 3.0 * x1 - 2.0 * t0 - t1, 2.0 * x0 - 2.0 * x1 + t0 + t1);
}
float calcCubicPolynomial( float t, vec4 c ) {

			float t2 = t * t;
			float t3 = t2 * t;
			return c[0] + c[1] * t + c[2] * t2 + c[3] * t3;
		}
vec4 initNonuniformCatmullRom( float x0, float x1, float x2, float x3, float dt0, float dt1, float dt2 ) {

			// compute tangents when parameterized in [t1,t2]
			float t1 = ( x1 - x0 ) / dt0 - ( x2 - x0 ) / ( dt0 + dt1 ) + ( x2 - x1 ) / dt1;
			float t2 = ( x2 - x1 ) / dt1 - ( x3 - x1 ) / ( dt1 + dt2 ) + ( x3 - x2 ) / dt2;

			// rescale tangents for parametrization in [0,1]
			t1 *= dt1;
			t2 *= dt1;

			return initCubicPolynomial( x1, x2, t1, t2 );

		}

vec3 sampleCurve(float t) {
    // this is my curve?
    vec3 points[5];

    points[0] = texelFetch(curveData,ivec2(0, index), 0).rgb * 0.25;
    points[1] = texelFetch(curveData,ivec2(1, index), 0).rgb * 0.25;
    points[2] = texelFetch(curveData,ivec2(2, index), 0).rgb * 0.25;
    points[3] = texelFetch(curveData,ivec2(3, index), 0).rgb * 0.25;
    points[4] = texelFetch(curveData,ivec2(4, index), 0).rgb * 0.25;
    int numPoints = 5;

		vec3 point = vec3(0,0,0);

		int l = numPoints;

		float p = float( l - 1 ) * t;
		int intPoint = int(floor( p ));
		float weight = p - float(intPoint);

		if ( weight == 0.0 && intPoint == (l - 1) ) {

			intPoint = l - 2;
			weight = 1.0;

		}

		vec3 p0, p3; // 4 points (p1 & p2 defined below)

		if ( intPoint > 0 ) {

			p0 = points[ ( intPoint - 1 ) % l ];

		} else {

			// extrapolate first point
			//tmp.subVectors( points[ 0 ], points[ 1 ] ).add( points[ 0 ] );
      p0 = (points[0]-points[1]) + points[0];

		}

		vec3 p1 = points[ intPoint % l ];
		vec3 p2 = points[ ( intPoint + 1 ) % l ];

		if ( intPoint + 2 < l ) {

			p3 = points[ ( intPoint + 2 ) % l ];

		} else {

			// extrapolate last point
			//tmp.subVectors( points[ l - 1 ], points[ l - 2 ] ).add( points[ l - 1 ] );
			p3 = (points[l-1]-points[l-2])+points[l-1];

		}

    // init Centripetal / Chordal Catmull-Rom
    const float exponent = 0.25;
    float dt0 = dot(p0-p1, p0-p1);
    float dt1 = dot(p1-p2, p1-p2);
    float dt2 = dot(p2-p3, p2-p3);
    dt0 = pow( dt0, exponent );
    dt1 = pow( dt1, exponent );
    dt2 = pow( dt2, exponent );

    // safety check for repeated points
    if ( dt1 < 1e-4 ) dt1 = 1.0;
    if ( dt0 < 1e-4 ) dt0 = dt1;
    if ( dt2 < 1e-4 ) dt2 = dt1;

    vec4 px = initNonuniformCatmullRom( p0.x, p1.x, p2.x, p3.x, dt0, dt1, dt2 );
    vec4 py = initNonuniformCatmullRom( p0.y, p1.y, p2.y, p3.y, dt0, dt1, dt2 );
    vec4 pz = initNonuniformCatmullRom( p0.z, p1.z, p2.z, p3.z, dt0, dt1, dt2 );

		point = vec3(
			calcCubicPolynomial( weight, px ),
			calcCubicPolynomial( weight, py ),
			calcCubicPolynomial( weight, pz )
		);

		return point;
	}


#ifdef ROBUST
// ------
// Robust handling of Frenet-Serret frames with Parallel Transport
// ------
vec3 getTangent (vec3 a, vec3 b) {
  return normalize(b - a);
}

void rotateByAxisAngle (inout vec3 normal, vec3 axis, float angle) {
  // http://www.euclideanspace.com/maths/geometry/rotations/conversions/angleToQuaternion/index.htm
  // assumes axis is normalized
  float halfAngle = angle / 2.0;
  float s = sin(halfAngle);
  vec4 quat = vec4(axis * s, cos(halfAngle));
  normal = normal + 2.0 * cross(quat.xyz, cross(quat.xyz, normal) + quat.w * normal);
}

void createTube (float t, vec2 volume, out vec3 outPosition, out vec3 outNormal) {
  // Reference:
  // https://github.com/mrdoob/three.js/blob/b07565918713771e77b8701105f2645b1e5009a7/src/extras/core/Curve.js#L268
  float nextT = t + (1.0 / lengthSegments);

  // find first tangent
  vec3 point0 = sampleCurve(0.0);
  vec3 point1 = sampleCurve(1.0 / lengthSegments);

  vec3 lastTangent = getTangent(point0, point1);
  vec3 absTangent = abs(lastTangent);
  #ifdef ROBUST_NORMAL
    float min = MAX_NUMBER;
    vec3 tmpNormal = vec3(0.0);
    if (absTangent.x <= min) {
      min = absTangent.x;
      tmpNormal.x = 1.0;
    }
    if (absTangent.y <= min) {
      min = absTangent.y;
      tmpNormal.y = 1.0;
    }
    if (absTangent.z <= min) {
      tmpNormal.z = 1.0;
    }
  #else
    vec3 tmpNormal = vec3(1.0, 0.0, 0.0);
  #endif
  vec3 tmpVec = normalize(cross(lastTangent, tmpNormal));
  vec3 lastNormal = cross(lastTangent, tmpVec);
  vec3 lastBinormal = cross(lastTangent, lastNormal);
  vec3 lastPoint = point0;

  vec3 normal;
  vec3 tangent;
  vec3 binormal;
  vec3 point;
  float maxLen = (lengthSegments - 1.0);
  float epSq = EPSILON * EPSILON;
  for (float i = 1.0; i < lengthSegments; i += 1.0) {
    float u = i / maxLen;
    // could avoid additional sample here at expense of ternary
    // point = i == 1.0 ? point1 : sampleCurve(u);
    point = sampleCurve(u);
    tangent = getTangent(lastPoint, point);
    normal = lastNormal;
    binormal = lastBinormal;

    tmpVec = cross(lastTangent, tangent);
    if ((tmpVec.x * tmpVec.x + tmpVec.y * tmpVec.y + tmpVec.z * tmpVec.z) > epSq) {
      tmpVec = normalize(tmpVec);
      float tangentDot = dot(lastTangent, tangent);
      float theta = acos(clamp(tangentDot, -1.0, 1.0)); // clamp for floating pt errors
      rotateByAxisAngle(normal, tmpVec, theta);
    }

    binormal = cross(tangent, normal);
    if (u >= t) break;

    lastPoint = point;
    lastTangent = tangent;
    lastNormal = normal;
    lastBinormal = binormal;
  }

  // extrude outward to create a tube
  float tubeAngle = angle;
  float circX = cos(tubeAngle);
  float circY = sin(tubeAngle);

  // compute the TBN matrix
  vec3 T = tangent;
  vec3 B = binormal;
  vec3 N = -normal;

  // extrude the path & create a new normal
  outNormal.xyz = normalize(B * circX + N * circY);
  outPosition.xyz = point + B * volume.x * circX + N * volume.y * circY;
}
#else
// ------
// Fast version; computes the local Frenet-Serret frame
// ------
void createTube (float t, vec2 volume, out vec3 offset, out vec3 normal) {
  // find next sample along curve
  float nextT = t + (1.0 / lengthSegments);

  // sample the curve in two places
  vec3 current = sampleCurve(t);
  vec3 next = sampleCurve(nextT);

  // compute the TBN matrix
  vec3 T = normalize(next - current);
  vec3 B = normalize(cross(T, next + current));
  vec3 N = -normalize(cross(B, T));

  // extrude outward to create a tube
  float tubeAngle = angle;
  float circX = cos(tubeAngle);
  float circY = sin(tubeAngle);

  // compute position and normal
  normal.xyz = normalize(B * circX + N * circY);
  offset.xyz = current + B * volume.x * circX + N * volume.y * circY;
}
#endif

void main() {
  // current position to sample at
  // [-0.5 .. 0.5] to [0.0 .. 1.0]
  float t = (position * 2.0) * 0.5 + 0.5;

  // build our tube geometry
  vec2 volume = vec2(thickness);

  // build our geometry
  vec3 transformed;
  vec3 objectNormal;
  createTube(t, volume, transformed, objectNormal);

  // pass the normal and UV along
  vec3 transformedNormal = normalMatrix * objectNormal;
  vNormal = normalize(transformedNormal);
  vUv = uv.yx; // swizzle this to match expectations

  // project our vertex position
  vec4 mvPosition = modelViewMatrix * vec4(transformed, 1.0);
  vViewPosition = -mvPosition.xyz;
  gl_Position = projectionMatrix * mvPosition;
}
