# Visualization-of-Kerr-Blackhole-with-raychacing

This is a projet to visualise a black hole with tracing using OpenGl 3.3 and cgp-a library universal that can be deployed on differents OS including windows, linux and MacOs.

We use nature unit G=c=h=1. And for convinient, we choose the mass of black hole M=1.

To realise the visualisation, we used the ray-tracing. To execute ray-tracing with such setup, we create a rectangle that is fixed with the Window. For each pixel in the window, we calculate the direction of light with respect to a observer at the origin(so the light propagate straightly "before the screen"). With the origin and the direction we can use the numerical integration to perform a ray-tracing.

We didn't use the language of GR. In the opposite, we use an approximate form of GR's gravity to compute the trajactory of light. Each time it hits a object that is light source it remenbers the intensity of light that is generated bt the object until it hits a object that absord the light or goes to infinite long. A more realitic alogrithme based on the work of Interstella is implemented but still in test. For the black hole we add two bottons to modify the dynamic terms: "white hole" to repulse the 

There are three light sources are considered in the We didn't consider the reflection of light: the accretion disk, the planet and a background.

The accretion disk part refers another excellent precedent work(see:).

The planet strictly follows a newtonian trajectory ignoring its intereactions with accretion disk and blackhole. We use Kepler's six parameter to describe the mouvement of a planet. 

There are two types of background: spherical and plannel. When the light goes far enough to the origin we considere the the light goes to infinite far. At this time we record the position and the direction of light. With a pre-generated backgound starfield, we can deternmine the trajactory of light hit which star. And this time, "Background Scale" decides the number of stars and "Backgound distance" decides the density of the stars. As for the plane, we create a plane infinite large at z=-d. At this time,  "Background Scale" decides the size of checkboard and "Backgound distance" decides d.  

