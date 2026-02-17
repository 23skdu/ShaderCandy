# ShaderCandy Shader Gallery

This document provides a complete catalog of all available shaders in ShaderCandy, organized by category.

**Total Shaders:** 110 unique effects  
**Platforms:** macOS (Metal), Linux (OpenGL/GLSL)

---

## Table of Contents

- [Music-Reactive Shaders](#music-reactive-shaders) (10 shaders)
- [Visual Effects](#visual-effects) (49 shaders)
- [Character & Creature Shaders](#character--creature-shaders) (12 shaders)
- [Nature & Environment](#nature--environment) (12 shaders)
- [Geometric & Mathematical](#geometric--mathematical) (9 shaders)
- [Artistic & Cultural](#artistic--cultural) (8 shaders)
- [Audio Visualization](#audio-visualization) (4 shaders)
- [Neural Style Transfer](#neural-style-transfer) (1 shader)
- [Classic Shaders](#classic-shaders) (7 shaders)

---

## Music-Reactive Shaders

These shaders respond to audio input, creating dynamic visuals synchronized to your music.

### 8-Bit
**File:** `music/8bit.metal` / `music/8bit.frag`

Retro 8-bit platformer aesthetic with scrolling clouds, question blocks, coins, enemies, and a castle. Features pixelation effects and CRT scanlines for authentic retro gaming feel.

**Features:**
- Scrolling parallax clouds with animated faces
- Bouncing question blocks
- Collectible coins
- Walking enemies (Goomba-style)
- Castle at the end
- CRT scanline effects
- Audio reactivity (bass boost, treble sparkle)

---

### Classical
**File:** `music/classical.metal` / `music/classical.frag`

Elegant flowing ribbons in gold and ivory tones with 3D musical notes and treble clefs floating through space. Perfect for orchestral and classical music.

**Features:**
- Flowing ribbon curves
- 3D rendered musical notes
- Treble clef symbols
- Staff lines background
- Gold-to-ivory gradients
- Audio-responsive sparkle effects

---

### Electronic
**File:** `music/electronic.metal` / `music/electronic.frag`

Cyberpunk digital rain aesthetic with grid landscapes and neon pulses. Ideal for EDM, techno, and electronic music.

**Features:**
- Matrix-style digital rain
- Neon grid landscapes
- Pulsing beat visualization
- Synthwave color palette

---

### Heavy Metal
**File:** `music/heavymetal.metal` / `music/heavymetal.frag`

Dark industrial theme with fiery effects and aggressive motion. Perfect for metal, rock, and industrial genres.

**Features:**
- Industrial aesthetic
- Fire and ember effects
- Aggressive transitions
- Dark color palette

---

### Hip Hop
**File:** `music/hiphop.metal` / `music/hiphop.frag`

Urban graffiti-style visuals with street art influences and rhythmic patterns.

**Features:**
- Graffiti-style elements
- Urban color palette
- Beat-responsive motion

---

### Jazz
**File:** `music/jazz.metal` / `music/jazz.frag`

Smooth flowing patterns inspired by jazz improvisation and liquid motion.

**Features:**
- Smooth flowing curves
- Warm color transitions
- Improvisational motion

---

### Punk
**File:** `music/punk.metal` / `music/punk.frag`

Aggressive glitch aesthetic with distorted visuals and chaotic energy.

**Features:**
- Glitch effects
- Distorted motion
- High energy transitions
- Raw visual style

---

### Reggae
**File:** `music/reggae.metal` / `music/reggae.frag`

Tropical island vibes with beach sunsets and ocean themes.

**Features:**
- Tropical colors (green, yellow, red)
- Sunset gradients
- Beach/ocean elements
- Laid-back motion

---

### Soul
**File:** `music/soul.metal` / `music/soul.frag`

Warm flowing gradients with smooth, emotive transitions.

**Features:**
- Warm color palette
- Smooth gradients
- Emotive motion
- Velvet-like textures

---

### Vaporwave
**File:** `music/vaporwave.metal` / `music/vaporwave.frag`

80s retro nostalgia with pink/purple gradients, palm trees, and sunset grids.

**Features:**
- Synthwave grid landscape
- Pink and purple gradients
- Retro sun
- Palm tree silhouettes
- Scanline effects

---

## Visual Effects

Advanced procedural effects and mathematical visualizations.

### Area 51
**File:** `effects/area_51.metal` / `effects/area_51.frag`

Alien and UFO sighting at a secret desert base with multiple flying saucers, tractor beams, and cows grazing on the ground.

**Features:**
- 3D raymarched UFOs with animated lights
- Tractor beams pulling up cows
- Alien figures walking around
- Moon with craters
- Warning lights and searchlights
- Flickering aurora effects

---

### Astra Fractal
**File:** `effects/astra_fractal.metal` / `effects/astra_fractal.frag`

3D Mandelbox fractal tunnel with psychedelic color shifts, dynamic zoom, and vibrant rainbow colors.

**Features:**
- Mandelbox fractal with Julia set variation
- Dynamic zoom effect (1x to 4x)
- Vibrant rainbow colors
- Starfield background
- Chromatic aberration effects
- Camera rotation through tunnel

---

### Audio Spectrum
**File:** `effects/audio_spectrum.metal` / `effects/audio_spectrum.frag`

Real-time frequency analysis visualization with bars responding to different frequency bands.

**Features:**
- FFT frequency analysis
- Multiple visualization modes
- Color-coded frequency bands
- Beat detection

---

### Biolume Forest
**File:** `effects/biolume_forest.metal` / `effects/biolume_forest.frag`

Organic glowing mushrooms and vines in a dark void with bioluminescent effects and floating spores.

**Features:**
- Procedural mushroom generation
- Glowing caps and stems
- Bioluminescent spores
- Hanging vines
- Firefly particles
- Slow x-axis rotation
- Atmospheric fog

---

### Bloom
**File:** `effects/bloom.metal` / `effects/bloom.frag`

HDR glow effect with high dynamic range lighting simulation.

**Features:**
- HDR rendering
- Glow/bloom post-processing
- Light bleed effects
- Adjustable intensity

---

### Burning Ship
**File:** `effects/burning_ship.metal` / `effects/burning_ship.frag`

The Burning Ship fractal with detailed iterates and ship-like structures.

**Features:**
- Burning Ship fractal algorithm
- Detailed boundary exploration
- Color mapping based on iteration counts
- Zoom capability

---

### Calibration
**File:** `effects/calibration.metal` / `effects/calibration.frag`

Test pattern for display setup with color bars, gradients, and geometric patterns.

**Features:**
- Color bar test pattern
- Grayscale gradients
- Geometric alignment patterns
- Brightness/contrast reference

---

### Chrono Warp
**File:** `effects/chrono_warp.metal` / `effects/chrono_warp.frag`

Time-distortion tunnel with clock-inspired elements and temporal effects.

**Features:**
- Clock face elements
- Time-warp distortion
- Temporal color shifts
- Tunnel perspective

---

### Cosmic Kaleido
**File:** `effects/cosmic_kaleido.metal` / `effects/cosmic_kaleido.frag`

Mirror symmetry patterns inspired by kaleidoscopes with cosmic color schemes.

**Features:**
- Mirror symmetry (6-fold)
- Cosmic color palette
- Rotating pattern base
- Smooth transitions

---

### Deep Ocean Pulse
**File:** `effects/deep_ocean_pulse.metal` / `effects/deep_ocean_pulse.frag`

Underwater caustics and bubbles with deep blue color palette and bioluminescent effects.

**Features:**
- Caustic light patterns
- Rising bubbles
- Deep blue gradients
- Pulse effects synchronized to audio

---

### DNA Helix
**File:** `effects/dna_helix.metal` / `effects/dna_helix.frag`

3D double helix DNA structure rotating in space with glowing base pairs.

**Features:**
- Double helix geometry
- Rotating animation
- Glowing base pairs
- Molecular aesthetic

---

### Event Horizon
**File:** `effects/event_horizon.metal` / `effects/event_horizon.frag`

Black hole visualization with accretion disk and gravitational lensing effects.

**Features:**
- Black hole silhouette
- Accretion disk
- Gravitational lensing
- Particle jets
- Time dilation effects

---

### Fallout
**File:** `effects/fallout.metal` / `effects/fallout.frag`

Post-apocalyptic wasteland with radioactive effects and decay aesthetics.

**Features:**
- Radioactive green glow
- Decay textures
- Dust particles
- Ruined structures
- Toxic atmosphere

---

### Fluid Dynamics
**File:** `effects/fluid_dynamics.metal` / `effects/fluid_dynamics.frag`

Realistic fluid simulation with Navier-Stokes based flow patterns.

**Features:**
- Fluid flow simulation
- Velocity field visualization
- Vortex formation
- Interactive turbulence

---

### Fractal Zoom
**File:** `effects/fractal_zoom.metal` / `effects/fractal_zoom.frag`

Infinite Mandelbrot dive with smooth zooming and color cycling.

**Features:**
- Deep Mandelbrot zoom
- Smooth navigation
- Color cycling
- Detail preservation

---

### Hearts
**File:** `effects/hearts.metal` / `effects/hearts.frag`

3D floating hearts coming from all directions with romantic atmosphere.

**Features:**
- 3D heart shapes
- Multiple heart streams
- Camera rotation
- Pink and red color palette
- Sparkle effects
- Fog and depth

---

### IFS 3D
**File:** `effects/ifs_3d.metal` / `effects/ifs_3d.frag`

3D Iterated Function System fractal with customizable transformation parameters.

**Features:**
- IFS fractal generation
- 3D structure
- Customizable transforms
- Recursive detail

---

### Julia 3D
**File:** `effects/julia_3d.metal` / `effects/julia_3d.frag`

3D Julia set fractal with complex mathematical visualization.

**Features:**
- 3D Julia set
- Quaternion mathematics
- Deep zoom capability
- Smooth coloring

---

### Julia 4D
**File:** `effects/julia_4d.metal` / `effects/julia_4d.frag`

4D Julia set projection with hypercomplex number visualization.

**Features:**
- 4D to 3D projection
- Hypercomplex mathematics
- Animated morphing
- Rich detail

---

### Julia Bulb
**File:** `effects/julia_bulb.metal` / `effects/julia_bulb.frag`

Julia set rendered as a 3D bulb-like structure.

**Features:**
- Bulb-shaped fractal
- 3D raymarching
- Smooth color gradients
- Rotating animation

---

### Julia Set
**File:** `effects/julia_set.metal` / `effects/julia_set.frag`

2D Julia set visualization with interactive parameter control.

**Features:**
- 2D Julia set
- Interactive parameters
- Smooth gradients
- High precision

---

### Kaleidoscopic Tunnel
**File:** `effects/kaleidoscopic_tunnel.metal` / `effects/kaleidoscopic_tunnel.frag`

Psychedelic tunnel with kaleidoscopic patterns and vibrant colors.

**Features:**
- Tunnel perspective
- Kaleidoscope patterns
- Color cycling
- Rotation effects

---

### KIFS
**File:** `effects/kifs.metal` / `effects/kifs.frag`

Kaleidoscopic Iterated Function System fractal with folded space aesthetics.

**Features:**
- KIFS algorithm
- Folded geometric patterns
- Symmetric design
- Colorful output

---

### Liquid Aura
**File:** `effects/liquid_aura.metal` / `effects/liquid_aura.frag`

Fluid energy simulation with smooth flowing motion and ethereal glow.

**Features:**
- Fluid dynamics
- Energy flows
- Smooth gradients
- Ethereal glow

---

### Liquid Gradient
**File:** `effects/liquid_gradient.metal` / `effects/liquid_gradient.frag`

Smooth flowing colors with liquid-like motion and organic transitions.

**Features:**
- Smooth color transitions
- Liquid motion
- Organic shapes
- Soft gradients

---

### Mandelbox
**File:** `effects/mandelbox.metal` / `effects/mandelbox.frag`

Box-based fractal with fold and scale operations creating complex structures.

**Features:**
- Mandelbox algorithm
- Fold operations
- Box geometry
- Detailed exploration

---

### Mandelbrot 3D
**File:** `effects/mandelbrot_3d.metal` / `effects/mandelbrot_3d.frag`

3D extrusion of the classic Mandelbrot set with volumetric depth.

**Features:**
- 3D Mandelbrot extrusion
- Volumetric rendering
- Depth-based coloring
- Zoom capability

---

### Mandelbrot Set
**File:** `effects/mandelbrot_set.metal` / `effects/mandelbrot_set.frag`

Classic fractal explorer with deep zoom and smooth coloring.

**Features:**
- Deep zoom capability
- Smooth coloring algorithm
- Interactive exploration
- High precision math

---

### Mandelbulb
**File:** `effects/mandelbulb.metal` / `effects/mandelbulb.frag`

3D Mandelbrot set (Mandelbulb) with volumetric rendering.

**Features:**
- 3D Mandelbulb fractal
- Volumetric rendering
- Ray marching
- Complex surface detail

---

### Mandelbulb 3D
**File:** `effects/mandelbulb_3d.metal` / `effects/mandelbulb_3d.frag`

Alternative 3D Mandelbrot rendering with enhanced detail.

**Features:**
- 3D Mandelbulb variation
- Enhanced detail
- Ray marching
- Complex surface detail

---

### Mind Palace
**File:** `effects/mind_palace.metal` / `effects/mind_palace.frag`

Infinite shifting architectural rooms with rotating perspectives and appearing/disappearing cross beams.

**Features:**
- Architectural structures
- Rotating camera perspectives
- Appearing/disappearing beams
- Glowing hieroglyphs
- Color-shifting patterns
- Multiple light sources

---

### Mushroom
**File:** `effects/mushroom.metal` / `effects/mushroom.frag`

3D rotating neon rainbow colored mushrooms as particles on a fractal neon background. Features organic mushroom shapes with caps and stalks, rotating on the X-axis at different heights and sizes.

**Features:**
- SDF-based mushroom caps and stalks
- 40 rotating mushroom particles at varied heights
- Fractal neon background using multi-layer noise
- Rainbow color shifting effect over time
- X-axis rotation for each mushroom particle
- Glow effect based on distance field

---

### Nebula
**File:** `effects/nebula.metal` / `effects/nebula.frag`

Cosmic gas clouds with volumetric rendering and starfield backdrop.

**Features:**
- Volumetric gas clouds
- Starfield background
- Colorful nebula clouds
- Depth layering

---

### Neon Pulse
**File:** `effects/neon_pulse.metal` / `effects/neon_pulse.frag`

Synthwave grid landscape with neon lights and retro aesthetic.

**Features:**
- Retro grid floor
- Neon light strips
- Synthwave aesthetic
- Sunset gradient

---

### Neural Nexus
**File:** `effects/neural_nexus.metal` / `effects/neural_nexus.frag`

AI-inspired network visualization with interconnected nodes and data flows.

**Features:**
- Network nodes
- Data flow visualization
- AI aesthetic
- Connected pathways

---

### Newton
**File:** `effects/newton.metal` / `effects/newton.frag`

Newton fractal based on Newton's method for finding polynomial roots.

**Features:**
- Newton's method visualization
- Root finding basins
- Colorful convergence regions
- Mathematical precision

---

### Particles
**File:** `effects/particles.metal` / `effects/particles.frag`

GPU particle system with thousands of interactive particles.

**Features:**
- Thousands of particles
- GPU acceleration
- Interactive forces
- Collision detection

---

### Plasma
**File:** `effects/plasma.metal` / `effects/plasma.frag`

Classic demo scene plasma effect with vibrant color waves.

**Features:**
- Plasma wave patterns
- Demo scene aesthetic
- Animated colors
- Mathematical patterns

---

### Prism Core
**File:** `effects/prism_core.metal` / `effects/prism_core.frag`

Crystal refraction with light splitting into spectral colors.

**Features:**
- Crystal geometry
- Light refraction
- Spectral colors
- Transparency effects

---

### Quantum Crystalline
**File:** `effects/quantum_crystalline.metal` / `effects/quantum_crystalline.frag`

Quantum field visualization with crystalline structures and probability waves.

**Features:**
- Crystalline structures
- Probability waves
- Quantum field aesthetic
- Mathematical precision

---

### Quantum Field
**File:** `effects/quantum_field.metal` / `effects/quantum_field.frag`

Visualization of quantum field fluctuations and probability distributions.

**Features:**
- Quantum field simulation
- Probability waves
- Particle-like effects
- Wave interference patterns

---

### Raymarch Sculpture
**File:** `effects/raymarch_sculpture.metal` / `effects/raymarch_sculpture.frag`

Abstract sculptural forms created through raymarching with organic shapes.

**Features:**
- Raymarched sculpture
- Organic forms
- Smooth surfaces
- Dynamic lighting

---

### Reaction Diffusion
**File:** `effects/reaction_diffusion.metal` / `effects/reaction_diffusion.frag`

Chemical pattern formation simulating Gray-Scott reaction-diffusion.

**Features:**
- Gray-Scott model
- Organic patterns
- Chemical simulation
- Evolving structures

---

### Retro Robot
**File:** `effects/retro_robot.metal` / `effects/retro_robot.frag`

Vintage sci-fi aesthetic with robot motifs and retro-futuristic elements.

**Features:**
- Retro sci-fi aesthetic
- Robot motifs
- Vintage color palette
- Mechanical elements

---

### Sierpinski
**File:** `effects/sierpinski.metal` / `effects/sierpinski.frag`

Sierpinski triangle and its 3D variant, the Sierpinski tetrahedron.

**Features:**
- Sierpinski fractal
- Recursive subdivision
- 3D tetrahedron variant
- Infinite detail

---

### Starfield Warp
**File:** `effects/starfield_warp.metal` / `effects/starfield_warp.frag`

Hyperspace travel effect with stars stretching into light trails.

**Features:**
- Starfield generation
- Warp speed effect
- Light trails
- Speed transition

---

### Starship HUD
**File:** `effects/starship_hud.metal` / `effects/starship_hud.frag`

Sci-fi interface elements with targeting systems and ship telemetry.

**Features:**
- HUD interface elements
- Targeting systems
- Ship telemetry
- Sci-fi aesthetic

---

### Voronoi Cells
**File:** `effects/voronoi_cells.metal` / `effects/voronoi_cells.frag`

Geometric tessellation with Voronoi diagram patterns.

**Features:**
- Voronoi diagram
- Cell borders
- Color gradients
- Animated centers

---

### Vortex Dream
**File:** `effects/vortex_dream.metal` / `effects/vortex_dream.frag`

Swirling color tunnel with hypnotic rotation and smooth gradients.

**Features:**
- Vortex/tunnel effect
- Swirling colors
- Hypnotic rotation
- Smooth gradients

---

## Character & Creature Shaders

### Aquatic
**File:** `aquatic.metal` / `aquatic.frag`

Underwater life scene with 3D depth layers, dark blue waves, and fish silhouettes.

**Features:**
- 3D depth layers (far, middle, near)
- Multiple dark blue wave layers
- Fish silhouettes
- Rising bubbles
- Caustic lighting effects
- Depth-based fog

---

### CapMan
**File:** `capman.metal` / `capman.frag`

Pac-Man style game board with maze walls, dots, and ghosts.

**Features:**
- Authentic Pac-Man maze
- Collectible dots and power pellets
- Four ghosts with unique colors
- Animated Pac-Man with wedge mouth
- Arcade-style lighting

---

### Dragon
**File:** `dragon.metal` / `dragon.frag`

Mystical dragon eye with 3D blinking animation and detailed scales.

**Features:**
- 3D raymarched eye
- Blinking eyelids animation
- Fiery orange/red iris
- Detailed scales
- Pupil reflection
- Fire particles

---

### Dwarves
**File:** `dwarves.metal` / `dwarves.frag`

Underground forge scene with 3D dwarves working at anvils.

**Features:**
- 3D raymarched dwarves
- Beards and helmets
- Battle axes
- Underground cave
- Forge/furnace with fire
- Stone pillars

---

### Elves
**File:** `elves.metal` / `elves.frag`

Mystical forest elves with pointed ears, bows, and flowing hair.

**Features:**
- 3D raymarched elves
- Pointed ears
- Bows and arrows
- Flowing golden hair
- Forest setting with trees
- Magic wisps/fairies

---

### Frog
**File:** `frog.metal` / `frog.frag`

Pond life with lily pad, water ripples, and sun orbit in the sky.

**Features:**
- 3D raymarched frog
- Lily pad platform
- Water ripples
- Sun orbit across sky
- Dynamic sky gradient
- X-axis camera rotation

---

### Knights
**File:** `knights.metal` / `knights.frag`

Medieval battle scene with armored knights and castle backdrop.

**Features:**
- Armored knights
- Castle architecture
- Battlefield setting
- Medieval atmosphere

---

### Orcs
**File:** `orcs.metal` / `orcs.frag`

Volcanic fortress warriors with 3D orcs, spiked armor, and weapons.

**Features:**
- 3D raymarched orcs
- Muscular bodies
- Tusks and war paint
- Spiked shoulder armor
- Giant battle axes
- Volcanic fortress setting
- Lava flows

---

### Owl
**File:** `owl.metal` / `owl.frag`

Night watch with 3D owls featuring detailed feathers and rotating heads.

**Features:**
- 3D raymarched owls
- Rotating heads
- Facial discs
- Detailed feathers
- Glowing yellow eyes
- Night sky with stars
- Tree branches

---

### Thieves
**File:** `thieves.metal` / `thieves.frag`

Stealth shadow scene with thieves hiding in darkness.

**Features:**
- Stealth aesthetic
- Shadow effects
- Dark color palette
- Hidden figures

---

### Unicorn
**File:** `unicorn.metal` / `unicorn.frag`

Magical creature with flowing rainbow mane and glowing spiral horn.

**Features:**
- 3D raymarched unicorn
- Flowing rainbow mane
- Animated tail
- Spiral glowing horn
- Magical particles
- Rainbow lighting effects

---

## Nature & Environment

### Alien Landscape
**File:** `alien_landscape.metal` / `alien_landscape.frag`

Extraterrestrial terrain with alien vegetation and multiple moons.

**Features:**
- Alien terrain generation
- Strange vegetation
- Multiple moons
- Atmospheric scattering

---

### Aurora
**File:** `aurora.metal` / `aurora.frag`

Northern lights dancing in the sky with ethereal curtains of color.

**Features:**
- Aurora borealis effect
- Colorful light curtains
- Animated movement
- Night sky backdrop

---

### Fireflies
**File:** `fireflies.metal` / `fireflies.frag`

Nighttime forest with floating firefly particles and ambient glow.

**Features:**
- Firefly particles
- Bioluminescent glow
- Night forest setting
- Ambient lighting

---

### Forest
**File:** `forest.metal` / `forest.frag`

Dense woodland scene with trees, foliage, and atmospheric depth.

**Features:**
- Procedural trees
- Dense foliage
- Atmospheric depth
- Lighting effects

---

### Galaxy
**File:** `galaxy.metal` / `galaxy.frag`

Spiral galaxy with billions of stars, dust lanes, and core brightness.

**Features:**
- Spiral galaxy structure
- Star generation
- Dust lanes
- Bright galactic core

---

### Nebula (Root)
**File:** `nebula.metal` / `nebula.frag`

Cosmic gas clouds with colorful emission and reflection nebulae.

**Features:**
- Volumetric nebula
- Emission colors
- Star illumination
- Deep space background

---

### Ocean
**File:** `ocean.metal` / `ocean.frag`

Open ocean scene with waves, foam, and dynamic water surface.

**Features:**
- Animated waves
- Foam generation
- Water reflections
- Dynamic surface

---

### Planet
**File:** `planet.metal` / `planet.frag`

3D rendered planet with atmosphere, clouds, and terrain.

**Features:**
- Planetary rendering
- Atmospheric glow
- Cloud layers
- Terrain detail

---

### Rain
**File:** `rain.metal` / `rain.frag`

Rainy scene with falling droplets, puddles, and wet surfaces.

**Features:**
- Falling rain
- Splash effects
- Wet surface reflections
- Atmospheric gloom

---

### Snow
**File:** `snow.metal` / `snow.frag`

Winter scene with snowfall, accumulation, and frosted landscape.

**Features:**
- Snowfall particles
- Accumulation effects
- Frosted surfaces
- Cold color palette

---

### Starfield
**File:** `starfield.metal` / `starfield.frag`

Dense starfield with varying star sizes and subtle color variations.

**Features:**
- Procedural stars
- Size variation
- Color diversity
- Subtle twinkling

---

### Thunderstorm
**File:** `thunderstorm.metal` / `thunderstorm.frag`

Dynamic storm with lightning, clouds, and heavy rain.

**Features:**
- Lightning bolts
- Storm clouds
- Heavy rain
- Flash effects

---

### Waterfall
**File:** `waterfall.metal` / `waterfall.frag`

Cascading waterfall with mist, spray, and rocky surroundings.

**Features:**
- Water flow simulation
- Mist and spray
- Rock formations
- Ambient moisture

---

## Geometric & Mathematical

### Cellular
**File:** `cellular.metal` / `cellular.frag`

Cellular automata patterns with evolving geometric structures.

**Features:**
- Cellular automaton rules
- Geometric patterns
- Evolving structures
- Colorful output

---

### Julia
**File:** `julia.metal` / `julia.frag`

Interactive 2D Julia set with adjustable parameters.

**Features:**
- 2D Julia set
- Adjustable c parameter
- Smooth coloring
- Real-time updates

---

### Lissajous
**File:** `lissajous.metal` / `lissajous.frag`

Lissajous curves with configurable frequencies and phase.

**Features:**
- Lissajous curve generation
- Adjustable frequencies
- Phase control
- Clean geometric lines

---

### Mandala
**File:** `mandala.metal` / `mandala.frag`

Intricate radial patterns inspired by traditional mandala art.

**Features:**
- Radial symmetry
- Detailed patterns
- Layered design
- Vibrant colors

---

### Mandelbrot (Root)
**File:** `mandelbrot.metal` / `mandelbrot.frag`

Classic 2D Mandelbrot set with deep zoom capability.

**Features:**
- 2D Mandelbrot set
- Zoom capability
- Smooth coloring
- Boundary detail

---

### Psychedelic
**File:** `psychedelic.metal` / `psychedelic.frag`

Mind-bending color patterns with warping and distortion effects.

**Features:**
- Color warping
- Distortion effects
- Pulsing patterns
- Vibrant colors

---

### Trigonometric
**File:** `trigonometric.metal` / `trigonometric.frag`

Mathematical function visualization with trigonometric patterns.

**Features:**
- Trig function plots
- Wave interference
- Pattern complexity
- Smooth gradients

---

### Wormhole
**File:** `wormhole.metal` / `wormhole.frag`

Space-time wormhole visualization with gravitational lensing.

**Features:**
- Wormhole tunnel
- Gravitational lensing
- Space distortion
- Star field background

---

## Artistic & Cultural

### Art Deco
**File:** `art_deco.metal` / `art_deco.frag`

Art deco geometric patterns with gold and black aesthetic.

**Features:**
- Art deco patterns
- Geometric lines
- Gold and black palette
- Symmetrical design

---

### Blackhole
**File:** `blackhole.metal` / `blackhole.frag`

Gravitational singularity with event horizon and accretion disk.

**Features:**
- Black hole rendering
- Event horizon
- Accretion disk
- Gravitational effects

---

### Byzantine
**File:** `byzantine.metal` / `byzantine.frag`

Byzantine-inspired mosaics with golden icons and religious imagery.

**Features:**
- Mosaic patterns
- Byzantine aesthetic
- Golden elements
- Religious iconography

---

### Celtic
**File:** `celtic.metal` / `celtic.frag`

Intricate Celtic knot patterns with interlacing designs.

**Features:**
- Celtic knots
- Interlacing patterns
- Traditional motifs
- Ornate design

---

### Egyptian
**File:** `egyptian.metal` / `egyptian.frag`

Ancient Egyptian theme with pyramids, hieroglyphs, and desert.

**Features:**
- Pyramid scenes
- Hieroglyphic patterns
- Desert landscape
- Ancient aesthetic

---

### Japanese
**File:** `japanese.metal` / `japanese.frag`

Japanese-inspired art with cherry blossoms, torii gates, and zen gardens.

**Features:**
- Cherry blossoms
- Torii gates
- Zen garden elements
- Traditional aesthetic

---

### Tribal
**File:** `tribal.metal` / `tribal.frag`

Tribal patterns with bold shapes and earth tones.

**Features:**
- Tribal patterns
- Bold geometric shapes
- Earth tone colors
- Primitive aesthetic

---

## Audio Visualization

### Audio Bars
**File:** `audio_bars.metal` / `audio_bars.frag`

Classic bar graph equalizer visualization with frequency spectrum display.

**Features:**
- Bar equalizer
- Frequency bands
- Beat detection
- Color gradients

---

### Audio Circular
**File:** `audio_circular.metal` / `audio_circular.frag`

Circular audio visualizer with radial frequency display.

**Features:**
- Circular display
- Radial frequency
- Symmetric patterns
- Glow effects

---

### Audio Wave
**File:** `audio_wave.metal` / `audio_wave.frag`

Waveform visualization showing amplitude over time.

**Features:**
- Waveform display
- Amplitude visualization
- Real-time updates
- Smooth curves

---

### Audio Ray Tracing
**File:** `audio/audio_ray_tracing.metal` / `audio/audio_ray_tracing.frag`

Acoustic visualization using ray tracing techniques to show sound propagation.

**Features:**
- Ray-traced audio visualization
- Sound wave propagation
- Acoustic simulation
- Real-time frequency response
- 3D spatial audio representation

---

## Neural Style Transfer

### Neural Style Blend
**File:** `neural/neural_style_blend.metal` / `neural/neural_style_blend.frag`

Artistic style transfer using neural networks to blend content and style images.

**Features:**
- Neural network-based style transfer
- Real-time processing
- Multiple style presets
- Adjustable style strength
- Content preservation

---

## Classic Shaders

### Checkerboard
**File:** `checkerboard.metal` / `checkerboard.frag`

Optical illusion pattern with animated checkerboard.

**Features:**
- Animated checkerboard
- Optical illusion effects
- High contrast
- Adjustable speed

---

### Flying Toasters
**File:** `flying_toasters.metal` / `flying_toasters.frag`

After Dark screensaver tribute with flying toasters and toast.

**Features:**
- Flying toasters
- Toast animation
- After Dark tribute
- Retro aesthetic

---

### Gradient Waves
**File:** `gradient_waves.metal` / `gradient_waves.frag`

Smooth flowing colors with wave-like motion.

**Features:**
- Smooth gradients
- Wave motion
- Color transitions
- Organic flow

---

### Plasma
**File:** `plasma.metal` / `plasma.frag`

Classic demo scene effect with animated plasma.

**Features:**
- Classic plasma effect
- Demo scene aesthetic
- Animated colors
- Mathematical patterns

---

### Ripples
**File:** `ripples.metal` / `ripples.frag`

Water ripple simulation with realistic wave propagation.

**Features:**
- Water ripple simulation
- Wave propagation
- Interactive drops
- Realistic physics

---

### Spiral
**File:** `spiral.metal` / `spiral.frag`

Hypnotic rotating spiral with color cycling.

**Features:**
- Rotating spiral
- Color cycling
- Hypnotic motion
- Adjustable speed

---

### Tunnel
**File:** `tunnel.metal` / `tunnel.frag`

Infinite corridor effect with perspective and motion.

**Features:**
- Infinite corridor
- Perspective motion
- Grid pattern
- Speed variation

---

## Technical Details

### Shader Compilation

**macOS (Metal):**
- Shaders compiled at runtime using Metal compiler
- Supports live reloading during development
- Uses `#include "ShaderInterop.h"` for uniform buffers

**Linux (OpenGL):**
- GLSL 4.5 / OpenGL 3.3 core profile
- Uses `base/common.glsl` for uniform definitions
- Fragment shaders implement `vec4 effect_main(vec2 centered, vec2 uv)`

### Uniform Buffer

All shaders receive the following uniforms:

```glsl
layout(std140) uniform Uniforms {
    float time;           // Current time in seconds
    float speed;          // Animation speed multiplier
    vec2 resolution;      // Viewport resolution
    vec2 mouse;           // Mouse position (normalized)
    float mouseButtons;   // Bitmask of mouse buttons
    float intensity;      // Effect intensity
    vec4 date;            // Current date/time
    int frame;            // Frame number
    float deltaTime;      // Time since last frame
    float alpha;          // Cross-fade factor
    float gravity;        // Gravity constant
};
```

### Performance

- **Target FPS:** 60 FPS at 1920x1080
- **Dynamic Resolution:** Automatically scales down on thermal throttling
- **Memory Budget:** Respects GPU memory limits
- **Metal Features:** Uses Metal Performance Shaders where available

### File Structure

```
shaders/
├── base/
│   ├── common.glsl      # GLSL common definitions
│   ├── common.metal     # Metal common definitions
│   ├── utils.metal      # Metal utility functions
│   └── default.metal    # Default shader
├── effects/             # Visual effects (49 shaders)
├── music/              # Music-reactive (10 shaders)
├── audio/               # Audio visualization (1 shader)
├── neural/              # Neural network effects (1 shader)
├── system/
│   └── debug_overlay.metal  # Debug visualization
└── [root]/              # Classic & character shaders (49 shaders)
```

---

## Contributing

To add a new shader:

1. Create both `.metal` (macOS) and `.frag` (Linux) versions
2. Place in appropriate subdirectory
3. Follow naming convention: `lowercase_with_underscores`
4. Implement the standard interface
5. Generate screenshot and thumbnail
6. Update this documentation

---

## License

All shaders are part of ShaderCandy and follow the project's license terms.
