const THREE = require('three');

module.exports = createLineGeometry;
function createLineGeometry (numSides = 8, subdivisions = 50, openEnded = false) {
  // create a base CylinderGeometry which handles UVs, end caps and faces
  const radius = 1;
  const length = 1;
  const baseGeometry = new THREE.CylinderGeometry(radius, radius, length, numSides, subdivisions, openEnded);

  // fix the orientation so X can act as arc length
  baseGeometry.rotateZ(Math.PI / 2);

  // compute the radial angle for each position for later extrusion
  const tmpVec = new THREE.Vector2();
  const xPositions = [];
  const angles = [];
  const uvs = [];
  const vertices = baseGeometry.attributes.position.array;
  const faceVertexUvs = baseGeometry.attributes.uv.array;
  const indices = baseGeometry.index.array;
//  const faceVertexUvs = baseGeometry.faceVertexUvs[0];

  // Now go through each face and un-index the geometry.
  for (let i = 0; i < indices.length; i+=3) {
    const a = indices[i];
    const b = indices[i+1];
    const c = indices[i+2];
    const v0 = new THREE.Vector3(vertices[a*3+0], vertices[a*3+1], vertices[a*3+2]);
    const v1 = new THREE.Vector3(vertices[b*3+0], vertices[b*3+1], vertices[b*3+2]);
    const v2 = new THREE.Vector3(vertices[c*3+0], vertices[c*3+1], vertices[c*3+2]);
    const verts = [ v0, v1, v2 ];
    const faceUvs = [
      new THREE.Vector2(faceVertexUvs[a*2+0], faceVertexUvs[a*2+1]), 
      new THREE.Vector2(faceVertexUvs[b*2+0], faceVertexUvs[b*2+1]), 
      new THREE.Vector2(faceVertexUvs[c*2+0], faceVertexUvs[c*2+1]), 
    ];//faceVertexUvs[i];

    // For each vertex in this face...
    verts.forEach((v, j) => {
      tmpVec.set(v.y, v.z).normalize();

      // the radial angle around the tube
      const angle = Math.atan2(tmpVec.y, tmpVec.x);
      angles.push(angle);

      // "arc length" in range [-0.5 .. 0.5]
      xPositions.push(v.x);

      // copy over the UV for this vertex
      uvs.push(faceUvs[j].toArray());
    });
  }

  // build typed arrays for our attributes
  const posArray = new Float32Array(xPositions);
  const angleArray = new Float32Array(angles);
  const uvArray = new Float32Array(uvs.length * 2);

  // unroll UVs
  for (let i = 0; i < posArray.length; i++) {
    const [ u, v ] = uvs[i];
    uvArray[i * 2 + 0] = u;
    uvArray[i * 2 + 1] = v;
  }

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.BufferAttribute(posArray, 1));
  geometry.setAttribute('angle', new THREE.BufferAttribute(angleArray, 1));
  geometry.setAttribute('uv', new THREE.BufferAttribute(uvArray, 2));

  // dispose old geometry since we no longer need it
  baseGeometry.dispose();
  return geometry;
}
