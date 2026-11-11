// RAKIA crew: a group of 3D cartoon astronauts whose heads and eyes follow
// the pointer. Original characters built from three.js primitives, in the
// clay style of the CC BY 4.0 Spline scene "100 followers" by heyvlad; each
// wears a NASA-inspired spacesuit with RAKIA's own mission patches (no NASA
// insignia). Loaded from the app's own origin; exposes window.rakiaCrew.
import * as THREE from './vendor/three.module.min.js';

const TAU = Math.PI * 2;
const reducedMotion = () =>
  window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

// A seeded random, so the crew looks the same on every visit.
function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ---------------------------------------------------------------- textures

function canvasTexture(w, h, draw) {
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 4;
  return t;
}

// RAKIA mission patches: a few original designs (orbit, star, planet).
function patchTexture(variant) {
  return canvasTexture(256, 256, (g, w) => {
    const r = w / 2;
    const rims = ['#f4f6fa', '#f0b23a', '#f4f6fa', '#d9dee8'];
    const fills = ['#1b2a5c', '#2b1f5c', '#123d4a', '#5a1f2b'];
    g.fillStyle = rims[variant % 4];
    g.beginPath(); g.arc(r, r, r, 0, TAU); g.fill();
    g.fillStyle = fills[variant % 4];
    g.beginPath(); g.arc(r, r, r * 0.86, 0, TAU); g.fill();
    g.save();
    g.translate(r, r);
    g.rotate(-0.5);
    g.strokeStyle = '#f08a24';
    g.lineWidth = 12;
    g.beginPath(); g.ellipse(0, 0, r * 0.68, r * 0.26, 0, 0, TAU); g.stroke();
    g.restore();
    g.fillStyle = variant % 2 ? '#6fc4d1' : '#ffffff';
    g.beginPath(); g.arc(r, r, r * 0.22, 0, TAU); g.fill();
    g.fillStyle = '#ffffff';
    for (const [x, y, s] of [[0.68, 0.32, 0.05], [0.3, 0.7, 0.035], [0.72, 0.7, 0.03]]) {
      g.beginPath(); g.arc(w * x, w * y, w * s, 0, TAU); g.fill();
    }
    g.font = 'bold 34px sans-serif';
    g.textAlign = 'center';
    g.fillText('RAKIA', r, w * 0.9);
  });
}

// Fine fabric weave for the suit, as a bump map.
const fabric = () =>
  canvasTexture(256, 256, (g, w, h) => {
    const rand = rng(11);
    g.fillStyle = '#808080';
    g.fillRect(0, 0, w, h);
    for (let i = 0; i < 2400; i++) {
      const v = 110 + Math.floor(rand() * 40);
      g.fillStyle = `rgb(${v},${v},${v})`;
      g.fillRect(rand() * w, rand() * h, 2, 2);
    }
    g.strokeStyle = 'rgba(90,90,90,0.5)';
    for (let y = 0; y < h; y += 8) {
      g.beginPath(); g.moveTo(0, y); g.lineTo(w, y); g.stroke();
    }
  });

function spaceTexture() {
  return canvasTexture(1024, 1024, (g, w, h) => {
    const grd = g.createRadialGradient(w * 0.5, h * 0.42, 40, w * 0.5, h * 0.5, w * 0.72);
    grd.addColorStop(0, '#5a2fa8');
    grd.addColorStop(0.45, '#2a1960');
    grd.addColorStop(1, '#0c0a24');
    g.fillStyle = grd;
    g.fillRect(0, 0, w, h);
    const rand = rng(7);
    for (let i = 0; i < 260; i++) {
      g.fillStyle = `rgba(255,255,255,${0.15 + rand() * 0.55})`;
      g.beginPath();
      g.arc(rand() * w, rand() * h * 0.8, 0.5 + rand() * 1.3, 0, TAU);
      g.fill();
    }
  });
}

// ---------------------------------------------------------------- materials

function materials() {
  const weave = fabric();
  weave.wrapS = weave.wrapT = THREE.RepeatWrapping;
  weave.repeat.set(3, 3);
  return {
    suit: new THREE.MeshStandardMaterial({ color: 0xeef1f6, roughness: 0.72, bumpMap: weave, bumpScale: 0.6 }),
    suitShade: new THREE.MeshStandardMaterial({ color: 0xc9d0db, roughness: 0.8 }),
    glove: new THREE.MeshStandardMaterial({ color: 0xdfe4ec, roughness: 0.6 }),
    ring: new THREE.MeshStandardMaterial({ color: 0x2f5d9e, roughness: 0.3, metalness: 0.6 }),
    metal: new THREE.MeshStandardMaterial({ color: 0x9aa4b4, roughness: 0.35, metalness: 0.7 }),
    panel: new THREE.MeshStandardMaterial({ color: 0x5b6577, roughness: 0.5, metalness: 0.3 }),
    stripe: new THREE.MeshStandardMaterial({ color: 0xc62b2b, roughness: 0.6 }),
    white: new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.25 }),
    pupil: new THREE.MeshStandardMaterial({ color: 0x14161c, roughness: 0.2 }),
    brow: new THREE.MeshStandardMaterial({ color: 0x232026, roughness: 0.7 }),
    frame: new THREE.MeshStandardMaterial({ color: 0x15161b, roughness: 0.4, metalness: 0.4 }),
    glass: new THREE.MeshPhysicalMaterial({
      color: 0xcfe0ff, roughness: 0.04, metalness: 0, transparent: true, opacity: 0.16,
      clearcoat: 1, clearcoatRoughness: 0.05, depthWrite: false,
    }),
    lights: [0xff5a5f, 0xf5b83d, 0x46c47e].map(
      (c) => new THREE.MeshStandardMaterial({ color: c, emissive: c, emissiveIntensity: 1.2 }),
    ),
  };
}

// ------------------------------------------------------------- one astronaut

const SKINS = [0xe7b48f, 0xc98f6a, 0x8d5a3c, 0xf1c9a8, 0xb07250, 0x6f4430, 0xe0a07c, 0xd7b199];
const PLAYFUL = [0x4f7cff, 0x46c47e, 0xa35cff, 0xff5a7a, 0xf0a33a];

// Expressions: brow tilt (radians, +inward), lid (0 open .. 1 closed),
// mouth ('smile', 'grin', 'flat', 'o', 'worry'), extras.
const LOOKS = [
  { tilt: 0.25, lid: 0.0, mouth: 'flat' },
  { tilt: -0.2, lid: 0.0, mouth: 'smile' },
  { tilt: 0.0, lid: 0.45, mouth: 'flat' },
  { tilt: -0.35, lid: 0.0, mouth: 'o' },
  { tilt: 0.1, lid: 0.0, mouth: 'grin' },
  { tilt: 0.35, lid: 0.2, mouth: 'worry' },
  { tilt: 0.0, lid: 0.0, mouth: 'smile', glasses: true },
  { tilt: -0.1, lid: 0.0, mouth: 'smile', wink: true },
];

function mouthMesh(kind, mat) {
  switch (kind) {
    case 'o':
      return new THREE.Mesh(new THREE.TorusGeometry(0.06, 0.022, 10, 20), mat);
    case 'flat':
      return new THREE.Mesh(new THREE.CapsuleGeometry(0.018, 0.14, 4, 8).rotateZ(Math.PI / 2), mat);
    default: {
      const arc = kind === 'grin' ? 2.4 : 1.7;
      const g = new THREE.TorusGeometry(kind === 'grin' ? 0.13 : 0.1, 0.022, 10, 24, arc);
      g.rotateZ(kind === 'worry' ? (Math.PI - arc) / 2 : -Math.PI / 2 - arc / 2 + Math.PI);
      if (kind !== 'worry') g.rotateZ(Math.PI);
      return new THREE.Mesh(g, mat);
    }
  }
}

function makeAstronaut(m, i, rand, patch) {
  const root = new THREE.Group();
  const look = LOOKS[i % LOOKS.length];
  const skinHex = i % 5 === 3 ? PLAYFUL[(i / 5) | 0 % PLAYFUL.length] : SKINS[i % SKINS.length];
  const skin = new THREE.MeshStandardMaterial({ color: skinHex, roughness: 0.62 });
  const skinDark = new THREE.MeshStandardMaterial({
    color: new THREE.Color(skinHex).multiplyScalar(0.75), roughness: 0.7,
  });

  // Torso, shoulders and backpack.
  const torso = new THREE.Mesh(new THREE.CapsuleGeometry(0.62, 0.9, 8, 24), m.suit);
  torso.position.y = -0.2;
  torso.scale.set(1, 1, 0.85);
  torso.castShadow = torso.receiveShadow = true;
  root.add(torso);
  const pack = new THREE.Mesh(new THREE.BoxGeometry(1.0, 1.0, 0.45), m.suitShade);
  pack.position.set(0, 0.05, -0.55);
  root.add(pack);
  for (const side of [-1, 1]) {
    const arm = new THREE.Mesh(new THREE.CapsuleGeometry(0.2, 0.62, 6, 16), m.suit);
    arm.position.set(side * 0.72, -0.18, 0.05);
    arm.rotation.z = side * 0.18;
    arm.castShadow = true;
    root.add(arm);
    const glove = new THREE.Mesh(new THREE.SphereGeometry(0.19, 20, 16), m.glove);
    glove.position.set(side * 0.82, -0.68, 0.12);
    root.add(glove);
    if (side === 1 && i % 3 === 0) {
      const band = new THREE.Mesh(new THREE.TorusGeometry(0.205, 0.04, 8, 24), m.stripe);
      band.position.set(0.74, 0.02, 0.05);
      band.rotation.x = Math.PI / 2;
      root.add(band);
    }
  }
  // Waist seam.
  const seam = new THREE.Mesh(new THREE.TorusGeometry(0.6, 0.025, 8, 40), m.suitShade);
  seam.position.y = -0.35;
  seam.rotation.x = Math.PI / 2;
  seam.scale.set(1, 0.85, 1);
  root.add(seam);

  // Chest control box with three glowing lights.
  const box = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.26, 0.12), m.panel);
  box.position.set(0.05, 0.12, 0.55);
  root.add(box);
  m.lights.forEach((mat, k) => {
    const l = new THREE.Mesh(new THREE.SphereGeometry(0.03, 10, 8), mat);
    l.position.set(-0.08 + k * 0.1, 0.16, 0.62);
    root.add(l);
  });
  // Mission patch on the chest.
  const p = new THREE.Mesh(
    new THREE.CircleGeometry(0.15, 32),
    new THREE.MeshStandardMaterial({ map: patch, roughness: 0.6 }),
  );
  p.position.set(-0.34, 0.2, 0.5);
  p.rotation.y = -0.45;
  root.add(p);

  // Neck ring the helmet sits in.
  const ring = new THREE.Mesh(new THREE.TorusGeometry(0.42, 0.07, 16, 48), m.ring);
  ring.position.y = 0.48;
  ring.rotation.x = Math.PI / 2;
  root.add(ring);

  // Head: turns towards the pointer. Eyes rotate within it.
  const head = new THREE.Group();
  head.position.y = 0.95;
  root.add(head);
  const skull = new THREE.Mesh(new THREE.SphereGeometry(0.5, 40, 32), skin);
  skull.castShadow = true;
  head.add(skull);
  for (const side of [-1, 1]) {
    const ear = new THREE.Mesh(new THREE.SphereGeometry(0.1, 16, 12), skin);
    ear.position.set(side * 0.49, -0.02, 0);
    ear.scale.set(0.6, 1, 1);
    head.add(ear);
  }
  const nose = new THREE.Mesh(new THREE.SphereGeometry(0.075, 16, 12), skinDark);
  nose.position.set(0, -0.06, 0.5);
  nose.scale.set(1, 1.2, 0.9);
  head.add(nose);
  const mouth = mouthMesh(look.mouth, skinDark.clone());
  mouth.material.color.multiplyScalar(0.6);
  mouth.position.set(0, -0.22, 0.46);
  head.add(mouth);

  const eyes = [];
  for (const side of [-1, 1]) {
    const socket = new THREE.Group();
    socket.position.set(side * 0.17, 0.08, 0.38);
    head.add(socket);
    const white = new THREE.Mesh(new THREE.SphereGeometry(0.13, 28, 20), m.white);
    white.scale.set(1, 1.12, 0.8);
    socket.add(white);
    // The pupil sits on a pivot at the eye's centre: rotating the pivot moves
    // the pupil across the eye's surface.
    const pivot = new THREE.Group();
    socket.add(pivot);
    const isX = look.wink && side === 1;
    if (isX) {
      // A wink: the eye closed in a soft curve.
      const lid = new THREE.Mesh(new THREE.TorusGeometry(0.07, 0.018, 8, 16, Math.PI), m.brow);
      lid.position.z = 0.11;
      lid.rotation.z = Math.PI;
      socket.add(lid);
      white.visible = false;
    } else {
      const pupil = new THREE.Mesh(new THREE.SphereGeometry(0.058, 20, 16), m.pupil);
      pupil.position.z = 0.095;
      pupil.scale.z = 0.5;
      pivot.add(pupil);
      const glint = new THREE.Mesh(new THREE.SphereGeometry(0.016, 8, 6), m.white);
      glint.position.set(-0.02, 0.025, 0.125);
      pivot.add(glint);
    }
    // Upper lid for sleepy looks and blinking.
    const lid = new THREE.Mesh(
      new THREE.SphereGeometry(0.14, 24, 12, 0, TAU, 0, Math.PI / 2),
      skin,
    );
    lid.scale.set(1.05, 1.2, 0.9);
    lid.rotation.x = -1.7;
    socket.add(lid);
    // Brow.
    const brow = new THREE.Mesh(new THREE.CapsuleGeometry(0.035, 0.16, 4, 10), m.brow);
    brow.rotation.z = Math.PI / 2 + side * look.tilt;
    brow.position.set(0, 0.2, 0.08);
    socket.add(brow);
    eyes.push({ socket, pivot, lid, brow, closed: isX, browY: 0.2 });
    if (look.glasses) {
      const rim = new THREE.Mesh(new THREE.TorusGeometry(0.15, 0.018, 8, 32), m.frame);
      rim.position.z = 0.13;
      socket.add(rim);
    }
  }
  if (look.glasses) {
    const bridge = new THREE.Mesh(new THREE.CapsuleGeometry(0.012, 0.06, 4, 6).rotateZ(Math.PI / 2), m.frame);
    bridge.position.set(0, 0.1, 0.52);
    head.add(bridge);
  }

  // Glass bubble helmet and its rim.
  const helmet = new THREE.Mesh(new THREE.SphereGeometry(0.72, 40, 32), m.glass);
  helmet.position.y = 0.92;
  helmet.renderOrder = 2;
  root.add(helmet);
  const rim = new THREE.Mesh(new THREE.TorusGeometry(0.5, 0.05, 12, 48), m.metal);
  rim.position.y = 0.4;
  rim.rotation.x = Math.PI / 2;
  root.add(rim);

  return {
    root,
    head,
    eyes,
    lidRest: look.lid,
    blinkAt: 1 + rand() * 5,
    blink: 0,
    phase: rand() * TAU,
    yaw: 0,
    pitch: 0,
    eyeYaw: 0,
    eyePitch: 0,
  };
}

// -------------------------------------------------------------- the crew

function layout(count) {
  // Rows from back to front, like a group photo: wider at the back.
  const rows = count <= 3 ? [count] : [5, 6, 5];
  const spots = [];
  rows.forEach((n, r) => {
    const depth = (rows.length - 1 - r) * -1.1;
    const lift = (rows.length - 1 - r) * 0.95;
    const spread = 1.35;
    for (let k = 0; k < n; k++) {
      const x = (k - (n - 1) / 2) * spread + (r % 2 ? 0 : 0.1);
      spots.push([x, lift, depth]);
    }
  });
  return spots.slice(0, count);
}

function mount(container, options = {}) {
  const compact = !!options.compact;
  const count = compact ? 3 : 16;
  if (!window.WebGLRenderingContext) throw new Error('WebGL is not available');

  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false, powerPreference: 'low-power' });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.domElement.style.display = 'block';
  renderer.domElement.style.width = '100%';
  renderer.domElement.style.height = '100%';
  renderer.domElement.setAttribute('aria-hidden', 'true');
  container.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const space = spaceTexture();
  scene.background = space;

  // Deep-space lighting: a soft key, violet and blue rims, a dim fill.
  scene.add(new THREE.HemisphereLight(0xc9c4ff, 0x1a1230, 0.6));
  const key = new THREE.DirectionalLight(0xfff4ea, 1.7);
  key.position.set(2.5, 6, 7);
  key.castShadow = true;
  key.shadow.mapSize.set(1024, 1024);
  key.shadow.camera.left = -8;
  key.shadow.camera.right = 8;
  key.shadow.camera.top = 6;
  key.shadow.camera.bottom = -4;
  key.shadow.radius = 4;
  scene.add(key);
  const rimBlue = new THREE.PointLight(0x3d6bff, 26, 18, 1.6);
  rimBlue.position.set(4.5, 0.5, 2.5);
  scene.add(rimBlue);
  const rimViolet = new THREE.PointLight(0xb04dff, 14, 18, 1.6);
  rimViolet.position.set(-4.5, 1.5, 2.5);
  scene.add(rimViolet);

  const m = materials();
  const patches = [0, 1, 2, 3].map(patchTexture);
  const rand = rng(2026);
  const crew = [];
  const group = new THREE.Group();
  scene.add(group);
  layout(count).forEach(([x, y, z], i) => {
    const a = makeAstronaut(m, compact ? i * 3 + 1 : i, rand, patches[i % patches.length]);
    a.root.position.set(x, y, z);
    a.root.rotation.y = -x * 0.05;
    const s = 0.92 + rand() * 0.14;
    a.root.scale.setScalar(s);
    group.add(a.root);
    crew.push(a);
  });

  // Floor and the mission console in front, as in a group shot.
  const floor = new THREE.Mesh(
    new THREE.BoxGeometry(30, 0.3, 24),
    new THREE.MeshStandardMaterial({ color: 0x17133a, roughness: 0.9 }),
  );
  floor.position.set(0, -1.12, 8);
  floor.receiveShadow = true;
  scene.add(floor);
  if (!compact) {
    const deskMat = new THREE.MeshStandardMaterial({ color: 0x2b2f3c, roughness: 0.5, metalness: 0.4 });
    const screen = new THREE.Mesh(new THREE.BoxGeometry(1.5, 0.95, 0.06), deskMat);
    screen.position.set(0, -0.4, 1.95);
    screen.rotation.x = -0.12;
    screen.castShadow = true;
    scene.add(screen);
    const glowMat = new THREE.MeshStandardMaterial({ color: 0x0f1530, emissive: 0x3a5cff, emissiveIntensity: 0.35 });
    const glow = new THREE.Mesh(new THREE.PlaneGeometry(1.36, 0.82), glowMat);
    glow.position.set(0, -0.4, 1.92);
    glow.rotation.set(-0.12, Math.PI, 0);
    scene.add(glow);
    const dot = new THREE.Mesh(new THREE.CircleGeometry(0.06, 20), new THREE.MeshBasicMaterial({ color: 0xffffff }));
    dot.position.set(0, -0.4, 1.99);
    dot.rotation.x = -0.12;
    scene.add(dot);
  }

  const camera = new THREE.PerspectiveCamera(compact ? 32 : 30, 1, 0.1, 100);
  const groupWidth = compact ? 3.6 : 8.0;
  const groupHeight = compact ? 2.6 : 4.6;
  const centerY = compact ? 0.35 : 0.75;

  function fit() {
    const w = Math.max(1, container.clientWidth);
    const h = Math.max(1, container.clientHeight);
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    // Far enough that the whole crew fits both across and down.
    const vFov = (camera.fov * Math.PI) / 180;
    const hFov = 2 * Math.atan(Math.tan(vFov / 2) * camera.aspect);
    const dist = Math.max(groupHeight / 2 / Math.tan(vFov / 2), groupWidth / 2 / Math.tan(hFov / 2)) + 0.8;
    camera.position.set(0, centerY + 0.9, dist);
    camera.lookAt(0, centerY, 0);
    camera.updateProjectionMatrix();
  }
  fit();
  const resize = new ResizeObserver(fit);
  resize.observe(container);

  // Pointer anywhere in the page: mouse, pen or touch. Only observed.
  const ndc = new THREE.Vector2(0, 0);
  let hasPointer = false;
  const onPointer = (e) => {
    const r = renderer.domElement.getBoundingClientRect();
    if (r.width === 0) return;
    ndc.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
    hasPointer = true;
  };
  const onLeave = () => { hasPointer = false; };
  window.addEventListener('pointermove', onPointer, { passive: true });
  window.addEventListener('pointerdown', onPointer, { passive: true });
  document.documentElement.addEventListener('pointerleave', onLeave);

  // Where the pointer is in the world: a plane in front of the crew.
  const ray = new THREE.Raycaster();
  const lookPlane = new THREE.Plane(new THREE.Vector3(0, 0, 1), -3.2);
  const target = new THREE.Vector3();
  const tmp = new THREE.Vector3();
  const clamp = (v, a) => Math.max(-a, Math.min(a, v));

  let visible = true;
  const io = new IntersectionObserver((entries) => {
    visible = entries.some((e) => e.isIntersecting);
  });
  io.observe(container);

  let last = performance.now();
  let frame = 0;
  let disposed = false;
  function tick(now) {
    if (disposed) return;
    frame = requestAnimationFrame(tick);
    if (!visible || document.hidden) {
      last = now;
      return;
    }
    const dt = Math.min(0.1, (now - last) / 1000);
    last = now;
    const still = reducedMotion();
    const t = now / 1000;
    const k = still ? 1 : 1 - Math.exp(-dt * 7);
    const ke = still ? 1 : 1 - Math.exp(-dt * 14);

    if (hasPointer) {
      ray.setFromCamera(ndc, camera);
      if (!ray.ray.intersectPlane(lookPlane, target)) target.set(0, centerY, 3.2);
    } else {
      target.set(Math.sin(t * 0.3) * (still ? 0 : 0.6), centerY + 0.3, 3.2);
    }

    for (const a of crew) {
      a.head.getWorldPosition(tmp);
      const dx = target.x - tmp.x;
      const dy = target.y - tmp.y;
      const dz = target.z - tmp.z;
      const yaw = clamp(Math.atan2(dx, dz), 0.55);
      const pitch = clamp(-Math.atan2(dy, Math.hypot(dx, dz)), 0.35);
      // The head turns part of the way; the eyes do the rest, within limits.
      a.yaw += (yaw * 0.55 - a.yaw) * k;
      a.pitch += (pitch * 0.5 - a.pitch) * k;
      a.head.rotation.set(a.pitch, a.yaw - a.root.rotation.y, 0);
      a.eyeYaw += (clamp(yaw - a.yaw, 0.5) - a.eyeYaw) * ke;
      a.eyePitch += (clamp(pitch - a.pitch, 0.35) - a.eyePitch) * ke;
      if (!still) {
        a.root.position.y += Math.sin(t * 1.4 + a.phase) * 0.0006; // breathing
      }
      // Blinks: each on its own clock.
      if (!still) {
        a.blinkAt -= dt;
        if (a.blinkAt <= 0) {
          a.blink = 1;
          a.blinkAt = 2.5 + Math.random() * 4.5;
        }
        a.blink = Math.max(0, a.blink - dt * 7);
      }
      const lidClose = Math.max(a.lidRest, a.blink > 0 ? 1 - Math.abs(a.blink * 2 - 1) : 0);
      for (const e of a.eyes) {
        e.pivot.rotation.set(a.eyePitch, a.eyeYaw, 0);
        // The lid is the top half of a shell: tipped back it is hidden, upright
    // it covers the top of the eye (sleepy), tipped forward the whole eye.
        e.lid.rotation.x = -1.7 + lidClose * 3.2;
        e.brow.position.y = e.browY + Math.max(0, -a.eyePitch) * 0.08;
      }
    }
    renderer.render(scene, camera);
  }
  frame = requestAnimationFrame(tick);

  return {
    dispose() {
      disposed = true;
      cancelAnimationFrame(frame);
      resize.disconnect();
      io.disconnect();
      window.removeEventListener('pointermove', onPointer);
      window.removeEventListener('pointerdown', onPointer);
      document.documentElement.removeEventListener('pointerleave', onLeave);
      scene.traverse((o) => {
        if (o.geometry) o.geometry.dispose();
        const mats = o.material ? (Array.isArray(o.material) ? o.material : [o.material]) : [];
        for (const mat of mats) {
          for (const key of ['map', 'bumpMap']) mat[key]?.dispose?.();
          mat.dispose();
        }
      });
      space.dispose();
      patches.forEach((p) => p.dispose());
      renderer.dispose();
      renderer.forceContextLoss();
      renderer.domElement.remove();
    },
  };
}

window.rakiaCrew = { mount };
window.dispatchEvent(new Event('rakia-crew-ready'));
