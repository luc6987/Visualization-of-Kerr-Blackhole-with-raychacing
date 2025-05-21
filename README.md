
## 🌌 Project Overview

The visualization is based on **ray tracing**. A screen-aligned rectangle (quad) is rendered in front of a virtual camera placed at the origin. For each pixel, we calculate the initial direction of a light ray as perceived by an observer at the origin. We then simulate the light’s trajectory using numerical integration.

We don’t directly use the full tensorial machinery of General Relativity (GR). Instead, we implement an **approximate gravitational model** inspired by GR to compute the deflection of light rays. Each time a ray hits a luminous object, it accumulates light intensity. The tracing continues until the ray is either absorbed or escapes to infinity.

> A more realistic algorithm, inspired by the rendering techniques used in *Interstellar*, is also implemented and available in experimental mode.

## ✨ Features

### 🔁 White Hole Mode

A toggle allows you to switch the black hole into a **white hole** mode, where it repels light rather than absorbing it.

### 💡 Light Sources

There are three types of light sources considered in the scene:

#### 1. Accretion Disk

The accretion disk implementation is based on excellent prior work (see reference below). It simulates glowing matter spiraling into the black hole.

#### 2. Planet

The planet follows a **Newtonian Keplerian orbit** defined by six classical orbital elements. It does not interact with the black hole or the accretion disk.

#### 3. Background

Two types of background rendering are available:

- **Spherical Starfield**:
  - A procedurally generated skybox of stars.
  - If a light ray escapes far enough, its final direction is used to determine which star it intersects.
  - `Background Scale`: Controls the number of visible stars.
  - `Background Distance`: Controls star density and the definition of "infinity".

- **Plane Background**:
  - A virtual checkerboard plane located at \( z = -d \).
  - `Background Scale`: Controls checker size.
  - `Background Distance`: Sets the value of \( d \), i.e., the plane’s distance.

## 🧮 Technical Details

- All ray tracing is performed in **GLSL fragment shaders**.
- Supported numerical integration methods:
  - Runge-Kutta 4 (RK4)
  - Verlet
  - Symplectic Euler
- Modular structure: easy to extend with new physical models or shaders.
- Real-time rendering with configurable visual parameters.

## 📚 Reference

The accretion disk model is based on the work by **[hydrogendeuteride](https://github.com/hydrogendeuteride)**.  
👉 [BlackHoleRayTracer](https://github.com/hydrogendeuteride/BlackHoleRayTracer)
