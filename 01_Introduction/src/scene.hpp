#pragma once


#include "cgp/cgp.hpp"
#include "environment.hpp"

// This definitions allow to use the structures: mesh, mesh_drawable, etc. without mentionning explicitly cgp::
using cgp::mesh;
using cgp::mesh_drawable;
using cgp::vec3;
using cgp::numarray;
using cgp::timer_basic;

// Variables associated to the GUI (buttons, etc)
struct gui_parameters {
	bool display_frame = false;
	int raytracing_step = 512;
	float raytracing_step_size = 0.05f;
	bool display_wireframe = false;
	bool realistic_raytracing=false;
};

struct BlackHole {
	bool show_blackhole = true;
	bool white = false;
	float a = 0.0f; // Kerr parameter
};

struct accretion_disk_parameters {
	bool display_accretion_disk = true;
	bool red_shift = true;
	bool doppler = true;
	bool temperature_realistic = true;
	float accretionTemp=20000.0f;
};

struct planet_parameters {
	// keppler's six parameters to define the planet orbit
	bool display_planet = true;
	float demi_grand_axe = 3.0f;
	float eccentricity = 0.0f;
	float inclination = 0.0f;
	float longtitude_du_noeud_ascendant = 0.0f;
	float argument_du_periapside = 0.0f;
	float mean_anomaly = 0.0f;
	float rp = 0.5f; // planet radius
	vec3 planet_color = vec3(0.63, 0.8, 0.13);
};

// The structure of the custom scene
struct scene_structure : cgp::scene_inputs_generic {
	
	// ****************************** //
	// Elements and shapes of the scene
	// ****************************** //
	camera_controller_first_person_euler camera_control;
	camera_projection_perspective camera_projection;
	window_structure window;

	mesh_drawable global_frame;          // The standard global frame
	environment_structure environment;   // Standard environment controler
	uniform_generic_structure additional_parameters; //Additional uniform paramteters 
	input_devices inputs;                // Storage for inputs status (mouse, keyboard, window dimension)
	gui_parameters gui;                  // Standard GUI element storage
	GLuint star_texture_id;
	planet_parameters planet;
	BlackHole blackhole;
	accretion_disk_parameters accretion_disk_parameters;
	// ****************************** //
	// Elements and shapes of the scene
	// ****************************** //

	timer_basic timer;
	double frequence =0;
	mesh_drawable screen_quad_drawable; // The screen quad to display the shader

	opengl_shader_structure screen_shader;
	// ****************************** //
	// Functions
	// ****************************** //

	void initialize();    // Standard initialization to be called before the animation loop
	void display_frame(); // The frame display to be called within the animation loop
	void display_gui();   // The display of the GUI, also called within the animation loop


	void mouse_move_event();
	void mouse_click_event();
	void keyboard_event();
	void idle_frame();

	void display_info();

};





