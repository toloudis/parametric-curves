const createTubeGeometry = require('../geom/createTubeGeometry');
const glslify = require('glslify');
const path = require('path');
const newArray = require('new-array');
const tweenr = require('tweenr')();
const isMobile = require('../util/isMobile');
const THREE = require('three');

const {
  randomFloat
} = require('../util/random');

function randomSpherePoint(x0,y0,z0,radius){
  var u = Math.random();
  var v = Math.random();
  var theta = 2 * Math.PI * u;
  var phi = Math.acos(2 * v - 1);
  var x = x0 + (radius * Math.sin(phi) * Math.cos(theta));
  var y = y0 + (radius * Math.sin(phi) * Math.sin(theta));
  var z = z0 + (radius * Math.cos(phi));
  return [x,y,z];
}

module.exports = function (app) {
  const nCurves = 8192*2;
  const curves = [];

  for (let i = 0; i < nCurves; ++i ) {
    let p = randomSpherePoint(0,0,0, 4.0);
    curves.push(p[0]);
    curves.push(p[1]);
    curves.push(p[2]);
    p = randomSpherePoint(0,0,0, 0.25);
    curves.push(p[0]);
    curves.push(p[1]);
    curves.push(p[2]);
    p = randomSpherePoint(0,0,0, 2.0);
    curves.push(p[0]);
    curves.push(p[1]);
    curves.push(p[2]);
  }
  const curveData = new Float32Array(curves);

  const nPointsPerCurve = 3;
  const nFloatsPerCurve = nPointsPerCurve*3;
  // put curve data into texture
  const curveTexture = new THREE.DataTexture(curveData, nPointsPerCurve, nCurves, THREE.RGBFormat, THREE.FloatType);

  const totalMeshes = nCurves;//isMobile ? 30 : 40;
  const isSquare = false;
  const subdivsPerControlPoint = 4;
  const subdivisions = (nPointsPerCurve) * subdivsPerControlPoint;//isMobile ? 200 : 300;

  const numSides = isSquare ? 4 : 8;
  const openEnded = false;
  const geometry = createTubeGeometry(numSides, subdivisions, openEnded);

  const baseMaterial = new THREE.RawShaderMaterial({
    glslVersion: THREE.GLSL3,
    vertexShader: glslify(path.resolve(__dirname, '../shaders/tube.vert')),
    fragmentShader: glslify(path.resolve(__dirname, '../shaders/tube.frag')),
    side: THREE.FrontSide,
    // extensions: {
    //   deriviatives: true
    // },
    defines: {
      lengthSegments: subdivisions.toFixed(1),
      ROBUST: true,//false,
      ROBUST_NORMALS: true, // can be disabled for a slight optimization
      FLAT_SHADED: isSquare
    },
    uniforms: {
      thickness: { type: 'f', value: 1 },
      time: { type: 'f', value: 0 },
      color: { type: 'c', value: new THREE.Color('#ff3030') },
      index: { type: 'f', value: 0 },
      radialSegments: { type: 'f', value: numSides },
      curveData: {type: 't', value: curveTexture}
    }
  });

  const lines = newArray(totalMeshes).map((_, i) => {
    const t = totalMeshes <= 1 ? 0 : i / (totalMeshes - 1);

    const material = baseMaterial.clone();
    material.uniforms = THREE.UniformsUtils.clone(material.uniforms);
    material.uniforms.index.value = i;//t;
    material.uniforms.thickness.value = randomFloat(0.005, 0.0075);
    material.uniforms.curveData.value = curveTexture;

    const mesh = new THREE.Mesh(geometry, material);
    mesh.frustumCulled = false; // to avoid ThreeJS errors
    return mesh;
  });

  // add to a parent container
  const container = new THREE.Object3D();
  lines.forEach(mesh => container.add(mesh));

  return {
    object3d: container,
    update,
    setPalette
  };

  // animate in a new color palette
  function setPalette (palette) {
    tweenr.cancel();
    lines.forEach((mesh, i) => {
      const uniforms = mesh.material.uniforms;
      uniforms.color.value.set(palette);
    });
  }

  function update (dt) {
    dt = dt / 1000;
    lines.forEach(mesh => {
      mesh.material.uniforms.time.value += dt;
    });
    const amplitude = 0.05;
    for (let ii = 0; ii < nCurves; ++ii ) {
      curveData[(ii*nFloatsPerCurve) + 0] += randomFloat(-amplitude, amplitude);
      curveData[(ii*nFloatsPerCurve) + 1] += randomFloat(-amplitude, amplitude);
      curveData[(ii*nFloatsPerCurve) + 2] += randomFloat(-amplitude, amplitude);
      curveData[(ii*nFloatsPerCurve) + 3] += randomFloat(-amplitude, amplitude);
      curveData[(ii*nFloatsPerCurve) + 4] += randomFloat(-amplitude, amplitude);
      curveData[(ii*nFloatsPerCurve) + 5] += randomFloat(-amplitude, amplitude);
      curveData[(ii*nFloatsPerCurve) + 6] += randomFloat(-amplitude, amplitude);
      curveData[(ii*nFloatsPerCurve) + 7] += randomFloat(-amplitude, amplitude);
      curveData[(ii*nFloatsPerCurve) + 8] += randomFloat(-amplitude, amplitude);
    }
    curveTexture.needsUpdate = true;
  }
};
