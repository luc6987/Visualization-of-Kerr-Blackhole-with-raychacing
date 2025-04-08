#include "scene.hpp"

using namespace cgp;

void scene_structure::initialize()
{
	std::cout << "Start function scene_structure::initialize()" << std::endl;

	// 摄像机初始化
	camera_control.initialize(inputs, window); 
	camera_control.set_rotation_axis_z();
	camera_control.look_at(
    { 0.0f, -10.0f, 5.0f }, // 摄像机位置
	{ 0.0f,  0.0f, 0.0f }, // 观察点
	{ 0.0f,  0.0f, 1.0f }  // 上方向
	);
	

	// 显示帮助信息
	display_info();

	// 创建辅助坐标系
	global_frame.initialize_data_on_gpu(mesh_primitive_frame());

	// 创建固定在屏幕上的全屏四边形（NDC [-1,1]）
	mesh screen_quad = mesh_primitive_quadrangle(
		{-1.0f, -1.0f, 0.0f},
		{ 1.0f, -1.0f, 0.0f},
		{ 1.0f,  1.0f, 0.0f},
		{-1.0f,  1.0f, 0.0f}
	);
	screen_quad_drawable.initialize_data_on_gpu(screen_quad);

	// 加载自定义光线追踪着色器
	screen_shader.load(
		project::path + "shaders/screen_quad/screen_quad.vert.glsl",
		project::path + "shaders/screen_quad/screen_quad.frag.glsl"
	);
	screen_quad_drawable.shader = screen_shader;

	std::cout << "End function scene_structure::initialize()" << std::endl;
}

void scene_structure::display_frame()
{   

	environment.uniform_generic.uniform_float["fov_y"] = camera_projection.field_of_view * 180.0f / Pi;
environment.uniform_generic.uniform_float["aspect_ratio"] = camera_projection.aspect_ratio;
environment.uniform_generic.uniform_vec2["resolution"] = {window.width, window.height};
environment.uniform_generic.uniform_int["show_blackhole"] = gui.show_blackhole ? 1 : 0;



	glDisable(GL_DEPTH_TEST); // 不需要深度测试
	timer.update();
	environment.uniform_generic.uniform_float["time"] = timer.t;

	// 绘制全屏四边形
	draw(screen_quad_drawable, environment);

	// 可选：坐标轴辅助框
	if (gui.display_frame)
		draw(global_frame, environment);
}

void scene_structure::display_gui()
{   ImGui::Checkbox("Show black hole", &gui.show_blackhole);
	ImGui::Checkbox("Frame", &gui.display_frame);
	ImGui::SliderFloat("camera_pov", &camera_projection.field_of_view, 0.0f, 5.0f);
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
