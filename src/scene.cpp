#include "scene.hpp"

using namespace cgp;

void scene_structure::initialize()
{
	std::cout << "Start function scene_structure::initialize()" << std::endl;

	// initialize the window
	camera_control.initialize(inputs, window); 
	camera_control.set_rotation_axis_z();
	camera_control.look_at(
    { 0.0f, 2.0f, 15.0f }, // camera position
	{ 0.0f,  0.0f, 0.0f }, // target point
	{ 0.0f,  0.0f, 1.0f }  // up direction
	);
	
	// initialize the projection
	display_info();

	// initialize the environment
	global_frame.initialize_data_on_gpu(mesh_primitive_frame());

	// create a quad to display the shader
	mesh screen_quad = mesh_primitive_quadrangle(
		{-1.0f, -1.0f, 0.0f},
		{ 1.0f, -1.0f, 0.0f},
		{ 1.0f,  1.0f, 0.0f},
		{-1.0f,  1.0f, 0.0f}
	);
	screen_quad_drawable.initialize_data_on_gpu(screen_quad);

	// load custom ray tracing shader

screen_shader.load(
	project::path + "shaders/screen_quad/screen_quad.vert.glsl",
	project::path + "shaders/screen_quad/screen_quad.frag.glsl"
);


	screen_quad_drawable.shader = screen_shader;

	std::cout << "\nScreen quad shader ID" << std::endl;
	std::cout << "-----------------------------------------------" << std::endl;
	std::cout << screen_shader.id << std::endl;
	std::cout << "-----------------------------------------------\n" << std::endl;
    
	std::cout << "End function scene_structure::initialize()" << std::endl;
}

// This function is called to display the frame
void scene_structure::display_frame()
{
	// 1. setup the environment
	environment.uniform_generic.uniform_int["background_type"] = environment.background.type;
	environment.uniform_generic.uniform_float["background_scale"] = environment.background.scale;
	environment.uniform_generic.uniform_float["background_distance"] = environment.background.distance;
	environment.uniform_generic.uniform_vec3["cam_pos"] = camera_control.camera_model.position();
	environment.uniform_generic.uniform_float["fov_y"] = camera_projection.field_of_view * 180.0f / Pi;
	environment.uniform_generic.uniform_float["aspect_ratio"] = camera_projection.aspect_ratio;
	environment.uniform_generic.uniform_vec2["resolution"] = {window.width, window.height};
	environment.uniform_generic.uniform_int["realistic_raytracing"] = gui.realistic_raytracing ? 1 : 0;

	// 2. setup the black hole related uniforms
	environment.uniform_generic.uniform_int["show_blackhole"] = blackhole.show_blackhole ? 1 : 0;
	environment.uniform_generic.uniform_int["white"] = blackhole.white ? 1 : 0;
	environment.uniform_generic.uniform_float["a"] = blackhole.a;

	// 3. setup the ray tracing related uniforms
	environment.uniform_generic.uniform_int["integrator"] = gui.integrator;
	environment.uniform_generic.uniform_int["max_steps"] = gui.raytracing_step;
	environment.uniform_generic.uniform_float["dt"] = gui.raytracing_step_size;

	// 4. setup the accretion disk related uniforms
	environment.uniform_generic.uniform_int["display_accretion_disk"] = accretion_disk_parameters.display_accretion_disk ? 1 : 0;
	environment.uniform_generic.uniform_int["red_shift"] = accretion_disk_parameters.red_shift ? 1 : 0;
	environment.uniform_generic.uniform_int["doppler"] = accretion_disk_parameters.doppler ? 1 : 0;
	environment.uniform_generic.uniform_int["temperature_realistic"] = accretion_disk_parameters.temperature_realistic ? 1 : 0;
	environment.uniform_generic.uniform_float["accretionTemp"] = accretion_disk_parameters.accretionTemp;

	// 5. setup the planet related uniforms
	environment.uniform_generic.uniform_int["display_planet"] = planet.display_planet ? 1 : 0;
	environment.uniform_generic.uniform_float["demi_grand_axe"] = planet.demi_grand_axe;
	environment.uniform_generic.uniform_float["eccentricity"] = planet.eccentricity;
	environment.uniform_generic.uniform_float["inclination"] = planet.inclination;
	environment.uniform_generic.uniform_float["longtitude_du_noeud_ascendant"] = planet.longtitude_du_noeud_ascendant;
	environment.uniform_generic.uniform_float["argument_du_periapside"] = planet.argument_du_periapside;
	environment.uniform_generic.uniform_float["mean_anomaly"] = planet.mean_anomaly;
	environment.uniform_generic.uniform_float["rp"] = planet.rp;
	environment.uniform_generic.uniform_vec3["planet_color"] = planet.planet_color;

	// 6. setup the camera orientation matrix
	mat4 const& cam_frame = camera_control.camera_model.matrix_frame();
	additional_parameters.uniform_mat3["cam_orientation"] = mat3(cam_frame);

	// 7. setup the time parameter
	glDisable(GL_DEPTH_TEST); 
	timer.update();
	additional_parameters.uniform_float["time"] = timer.t;

	// 8. draw the screen quad
	draw(screen_quad_drawable, environment, 1, true, additional_parameters);
	
	// 9. draw the global frame
	if (gui.display_frame)
		draw(global_frame, environment);
}

void scene_structure::display_gui()
{   cgp::vec3 cam_position = camera_control.camera_model.position();
	
	//parametre for the environment
	ImGui::SliderFloat("Background scale", &environment.background.scale, 0.1f, 10.0f);
	ImGui::SliderFloat("Background distance", &environment.background.distance, 1.0f, 50.0f);
	ImGui::Combo("Background type", &environment.background.type, "Checkerboard\0Gradient\0Stars\0");
	ImGui::Checkbox("Frame", &gui.display_frame);
	ImGui::Checkbox("Realistic raytracing(beta)",&gui.realistic_raytracing);

	//parametre for the camera
	ImGui::Text("Cam pos: (%.2f, %.2f, %.2f)", cam_position.x, cam_position.y, cam_position.z);
	vec3 cam_dir=normalize(-inverse(camera_control.camera_model.matrix_view())[2].xyz());
	ImGui::Text("Cam orientation: (%.2f, %.2f, %.2f)",cam_dir.x, cam_dir.y, cam_dir.z);
	ImGui::SliderInt("Raytracing step", &gui.raytracing_step, 1, 1000);
	ImGui::SliderFloat("Raytracing step size", &gui.raytracing_step_size, 0.001f, 0.1f);
	ImGui::SliderFloat("field of view", &camera_projection.field_of_view, 0.0f, 5.0f);
	ImGui::Combo("Integrator", &gui.integrator, "RK4\0Verlet\0Symplectic Euler\0");

	//parametre for the black hole
	ImGui::Checkbox("Show black hole", &blackhole.show_blackhole);
	ImGui::Checkbox("white hole", &blackhole.white);
	ImGui::SliderFloat("Kerr parameter", &blackhole.a, 0.0f, 1.0f);

	//parametre for the accretion disk
	ImGui::Checkbox("Accretion disk", &accretion_disk_parameters.display_accretion_disk);
	ImGui::Checkbox("red shift", &accretion_disk_parameters.red_shift);
	ImGui::Checkbox("doppler", &accretion_disk_parameters.doppler);
	ImGui::Checkbox("temperature realistic", &accretion_disk_parameters.temperature_realistic);
	ImGui::SliderFloat("accretion disk temperature", &accretion_disk_parameters.accretionTemp, 1000.0f, 40000.0f);

	//parametre for the planet
	ImGui::Text("Planet parameters");
	ImGui::Checkbox("Display planet", &planet.display_planet);
    ImGui::SliderFloat("Demi Grand Axe", &planet.demi_grand_axe, 0.0f, 10.0f);
	ImGui::SliderFloat("Eccentricity", &planet.eccentricity, 0.0f, 1.0f);
	ImGui::SliderFloat("Inclination", &planet.inclination, 0.0f, 3.14f);
	ImGui::SliderFloat("Longtitude du noeud ascendant", &planet.longtitude_du_noeud_ascendant, 0.0f, 3.14f);
	ImGui::SliderFloat("Argument du periapside", &planet.argument_du_periapside, 0.0f, 3.14f);
	ImGui::SliderFloat("Mean Anomaly", &planet.mean_anomaly, 0.0f, 3.14f);
	ImGui::SliderFloat("Planet radius", &planet.rp, 0.0f, 1.0f);
	ImGui::ColorEdit3("Planet color", &planet.planet_color.x);
	ImGui::Text("Planet color: (%.2f, %.2f, %.2f)", planet.planet_color.x, planet.planet_color.y, planet.planet_color.z);
}

void scene_structure::mouse_move_event()
{
	if (!inputs.keyboard.shift)
		camera_control.action_mouse_move(environment.camera_view);
}
void scene_structure::mouse_click_event()
{
	camera_control.action_mouse_click(environment.camera_view);
}
void scene_structure::keyboard_event()
{
	camera_control.action_keyboard(environment.camera_view);
}
void scene_structure::idle_frame()
{
	camera_control.idle_frame(environment.camera_view);
}

void scene_structure::display_info()
{
	std::cout << "\nCAMERA CONTROL:" << std::endl;
	std::cout << "-----------------------------------------------" << std::endl;
	std::cout << camera_control.doc_usage() << std::endl;
	std::cout << "-----------------------------------------------\n" << std::endl;

	std::cout << "\nSCENE INFO:" << std::endl;
	std::cout << "-----------------------------------------------" << std::endl;
	std::cout << "Raytracing quad setup ready. Edit `.frag` to start." << std::endl;
	std::cout << "-----------------------------------------------\n" << std::endl;
}
