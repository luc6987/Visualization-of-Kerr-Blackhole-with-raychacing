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
	bool show_blackhole = true;
    bool kerr=false;
    // Ajout de la nouvelle variable display_wireframe ici
    bool display_wireframe = false;
	bool display_accretion_disk = true;
	bool white = false;
	bool red_shift = false;
	bool doppler = false;
	bool temperature_realistic = false;
	float accretionTemp=10000.0f;
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





