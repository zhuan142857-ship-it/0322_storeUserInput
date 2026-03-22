package a

import "core:fmt"
import "core:slice"
import win "core:sys/windows"
import "core:time"
import "vendor:directx/d3d11"
import "vendor:directx/d3d_compiler"
import "vendor:directx/dxgi"


wnd_proc :: proc "stdcall" (
	hWnd: win.HWND,
	uMsg: win.UINT,
	wParam: win.WPARAM,
	lParam: win.LPARAM,
) -> (
	result: win.LRESULT,
) {
	context = context
	result = 0

	switch uMsg {
	case win.WM_KEYDOWN:
		if wParam == win.VK_ESCAPE {
			win.DestroyWindow(hWnd)
		}
		if wParam == win.VK_J {
			shape = Shape.square
		}
		if wParam == win.VK_K {
			shape = Shape.triangle
		}
		if wParam == win.VK_UP {
			time.stopwatch_start(&sw)


		}
	case win.WM_KEYUP:
		if wParam == win.VK_UP {
			time.stopwatch_reset(&sw)
		}

	case win.WM_LBUTTONDOWN:
		winXY := Position {
			x = cast(f32)win.GET_X_LPARAM(lParam),
			y = cast(f32)win.GET_Y_LPARAM(lParam),
		}

		bottomLeftXY: Position
		bottomLeftXY.x = winXY.x
		bottomLeftXY.y = 2160 - winXY.y

		realXY: Position
		realXY.x = bottomLeftXY.x * camera.scale + camera.offset.x
		realXY.y = bottomLeftXY.y * camera.scale + camera.offset.y

		currentInput: UserInput
		currentInput.position = realXY
		currentInput.shape = shape
		append(&inputs, currentInput)

		fmt.println(inputs[:])

		vertex_data := addShapeToRealData(inputs[:])
		defer delete(vertex_data)

		vertex_count = u32(len(vertex_data) / 6)

		mapped: d3d11.MAPPED_SUBRESOURCE
		device_context->Map(vertex_buffer, 0, .WRITE_DISCARD, {}, &mapped)
		dst := ([^]f32)(mapped.pData)
		for i in 0 ..< len(vertex_data) {
			dst[i] = vertex_data[i]
		}
		device_context->Unmap(vertex_buffer, 0)

	case win.WM_DESTROY:
		win.PostQuitMessage(0)

	case:
		result = win.DefWindowProcW(hWnd, uMsg, wParam, lParam)
	}

	return
}


main :: proc() {
	win.SetProcessDPIAware()
	hInstance := win.HINSTANCE(win.GetModuleHandleW(nil))


	// vertex_data = make([dynamic]f32, 0, 10000)
	// defer delete(vertex_data)
	// Open a window
	hWnd: win.HWND
	{
		window_class := win.WNDCLASSEXW {
			cbSize        = size_of(win.WNDCLASSEXW),
			style         = win.CS_HREDRAW | win.CS_VREDRAW,
			lpfnWndProc   = wnd_proc,
			hInstance     = hInstance,
			hIcon         = win.LoadIconW(nil, transmute(win.wstring)(win.IDI_APPLICATION)),
			hCursor       = win.LoadCursorW(nil, transmute(win.wstring)(win.IDC_ARROW)),
			lpszClassName = win.L(WINDOW_NAME),
			hIconSm       = win.LoadIconW(nil, transmute(win.wstring)(win.IDI_APPLICATION)),
		}

		class_atom := win.RegisterClassExW(&window_class)
		assert_messagebox(class_atom != 0, "RegisterClassExW failed")

		hWnd = win.CreateWindowExW(
			dwExStyle = 0,
			lpClassName = window_class.lpszClassName,
			lpWindowName = win.L(WINDOW_NAME),
			dwStyle = win.WS_POPUP | win.WS_VISIBLE,
			X = 0, // i32 min value, not zero
			Y = 0,
			nWidth = WIDTH,
			nHeight = HEIGHT,
			hWndParent = nil,
			hMenu = nil,
			hInstance = hInstance,
			lpParam = nil,
		)

		assert_messagebox(hWnd != nil, "CreateWindowExW failed")
	}


	// Create D3D11 Device and Context
	device: ^d3d11.IDevice
	{
		feature_levels := []d3d11.FEATURE_LEVEL{d3d11.FEATURE_LEVEL._11_0}
		creation_flags := d3d11.CREATE_DEVICE_FLAGS{.BGRA_SUPPORT}
		when ODIN_DEBUG {
			creation_flags += {.DEBUG}
		}

		res := d3d11.CreateDevice(
			pAdapter = nil,
			DriverType = .HARDWARE,
			Software = nil,
			Flags = creation_flags,
			pFeatureLevels = raw_data(feature_levels),
			FeatureLevels = u32(len(feature_levels)),
			SDKVersion = d3d11.SDK_VERSION,
			ppDevice = &device,
			pFeatureLevel = nil,
			ppImmediateContext = &device_context,
		)

		assert_messagebox(res, "CreateDevice failed")
	}
	defer device->Release()
	defer device_context->Release()


	// Debug layer
	when ODIN_DEBUG {
		device_debug: ^d3d11.IDebug
		device->QueryInterface(d3d11.IDebug_UUID, (^rawptr)(&device_debug))
		if device_debug != nil {
			info_queue: ^d3d11.IInfoQueue
			res := device_debug->QueryInterface(d3d11.IInfoQueue_UUID, (^rawptr)(&info_queue))
			if win.SUCCEEDED(res) {
				info_queue->SetBreakOnSeverity(.CORRUPTION, true)
				info_queue->SetBreakOnSeverity(.ERROR, true)

				allow_severities := []d3d11.MESSAGE_SEVERITY{.CORRUPTION, .ERROR, .INFO}

				filter := d3d11.INFO_QUEUE_FILTER {
					AllowList = {
						NumSeverities = u32(len(allow_severities)),
						pSeverityList = raw_data(allow_severities),
					},
				}
				info_queue->AddStorageFilterEntries(&filter)
				info_queue->Release()
			}
			device_debug->Release()
		}
	}


	// Create swapchain
	swapchain: ^dxgi.ISwapChain1
	{
		factory: ^dxgi.IFactory2
		{
			dxgi_device: ^dxgi.IDevice1
			res := device->QueryInterface(dxgi.IDevice1_UUID, (^rawptr)(&dxgi_device))
			defer dxgi_device->Release()
			assert_messagebox(res, "DXGI device interface query failed")

			dxgi_adapter: ^dxgi.IAdapter
			res = dxgi_device->GetAdapter(&dxgi_adapter)
			defer dxgi_adapter->Release()
			assert_messagebox(res, "DXGI adapter interface query failed")

			adapter_desc: dxgi.ADAPTER_DESC
			dxgi_adapter->GetDesc(&adapter_desc)
			fmt.printfln("Graphics device: %s", adapter_desc.Description)

			res = dxgi_adapter->GetParent(dxgi.IFactory2_UUID, (^rawptr)(&factory))
			assert_messagebox(res, "Get DXGI Factory failed")
		}
		defer factory->Release()

		swapchain_desc := dxgi.SWAP_CHAIN_DESC1 {
			Width = 0, // use window width/height
			Height = 0,
			Format = .B8G8R8A8_UNORM_SRGB,
			SampleDesc = {Count = 1, Quality = 0},
			BufferUsage = {.RENDER_TARGET_OUTPUT},
			BufferCount = 2,
			Scaling = .STRETCH,
			SwapEffect = .DISCARD,
			AlphaMode = .UNSPECIFIED,
			Flags = {},
		}

		res := factory->CreateSwapChainForHwnd(
			pDevice = device,
			hWnd = hWnd,
			pDesc = &swapchain_desc,
			pFullscreenDesc = nil,
			pRestrictToOutput = nil,
			ppSwapChain = &swapchain,
		)
		assert_messagebox(res, "CreateSwapChain failed")
	}
	defer swapchain->Release()


	// Create Framebuffer Render Target
	framebuffer_view: ^d3d11.IRenderTargetView
	{
		framebuffer: ^d3d11.ITexture2D
		res := swapchain->GetBuffer(0, d3d11.ITexture2D_UUID, (^rawptr)(&framebuffer))
		assert_messagebox(res, "Get Framebuffer failed")
		defer framebuffer->Release()

		res = device->CreateRenderTargetView(framebuffer, nil, &framebuffer_view)
		assert_messagebox(res, "CreateRenderTargetView failed")
	}
	defer framebuffer_view->Release()


	shader_src := #load("shaders.hlsl")

	// Create vertex shader
	vertex_shader_blob: ^d3d11.IBlob
	vertex_shader: ^d3d11.IVertexShader
	{
		// Note: this step can be performed offline. Save the blob buffer to a file using GetBufferPointer().
		compile_errors: ^d3d11.IBlob

		res := d3d_compiler.Compile(
			pSrcData = raw_data(shader_src),
			SrcDataSize = uint(len(shader_src)),
			pSourceName = "shaders.hlsl", // Not required, used for debug messages
			pDefines = nil,
			pInclude = nil,
			pEntrypoint = "vertex_main",
			pTarget = "vs_5_0",
			Flags1 = 0,
			Flags2 = 0,
			ppCode = &vertex_shader_blob,
			ppErrorMsgs = &compile_errors,
		)

		if win.FAILED(res) {
			if compile_errors != nil {
				error_str := compile_errors->GetBufferPointer()
				fmt.eprintln(error_str)
				compile_errors->Release()
			}
			assert_messagebox(res, "Vertex shader compilation failed")
		}

		res = device->CreateVertexShader(
			pShaderBytecode = vertex_shader_blob->GetBufferPointer(),
			BytecodeLength = vertex_shader_blob->GetBufferSize(),
			pClassLinkage = nil,
			ppVertexShader = &vertex_shader,
		)
		assert_messagebox(res, "Vertex shader creation failed")
	}
	defer vertex_shader_blob->Release()
	defer vertex_shader->Release()


	// Create pixel shader
	pixel_shader: ^d3d11.IPixelShader
	{
		pixel_shader_blob: ^d3d11.IBlob
		compile_errors: ^d3d11.IBlob

		res := d3d_compiler.Compile(
			pSrcData = raw_data(shader_src),
			SrcDataSize = uint(len(shader_src)),
			pSourceName = "shaders.hlsl", // Not required, used for debug messages
			pDefines = nil,
			pInclude = nil,
			pEntrypoint = "pixel_main",
			pTarget = "ps_5_0",
			Flags1 = 0,
			Flags2 = 0,
			ppCode = &pixel_shader_blob,
			ppErrorMsgs = &compile_errors,
		)
		defer pixel_shader_blob->Release()

		if win.FAILED(res) {
			if compile_errors != nil {
				error_str := compile_errors->GetBufferPointer()
				fmt.eprintln(error_str)
				compile_errors->Release()
			}
			assert_messagebox(res, "Pixel shader compilation failed")
		}

		res = device->CreatePixelShader(
			pShaderBytecode = pixel_shader_blob->GetBufferPointer(),
			BytecodeLength = pixel_shader_blob->GetBufferSize(),
			pClassLinkage = nil,
			ppPixelShader = &pixel_shader,
		)
		assert_messagebox(res, "Pixel shader creation failed")
	}
	defer pixel_shader->Release()


	// Create input layout
	input_layout: ^d3d11.IInputLayout
	{
		input_element_descs := []d3d11.INPUT_ELEMENT_DESC {
			{
				SemanticName = "position",
				SemanticIndex = 0,
				Format = .R32G32_FLOAT,
				InputSlot = 0,
				AlignedByteOffset = 0,
				InputSlotClass = .VERTEX_DATA,
				InstanceDataStepRate = 0,
			},
			{
				SemanticName = "color",
				SemanticIndex = 0,
				Format = .R32G32B32A32_FLOAT,
				InputSlot = 0,
				AlignedByteOffset = d3d11.APPEND_ALIGNED_ELEMENT,
				InputSlotClass = .VERTEX_DATA,
				InstanceDataStepRate = 0,
			},
		}

		res := device->CreateInputLayout(
			pInputElementDescs = raw_data(input_element_descs),
			NumElements = u32(len(input_element_descs)),
			pShaderBytecodeWithInputSignature = vertex_shader_blob->GetBufferPointer(),
			BytecodeLength = vertex_shader_blob->GetBufferSize(),
			ppInputLayout = &input_layout,
		)
		assert_messagebox(res, "Input layout creation failed")
		// vertex_shader_blob is safe to release now
	}
	defer input_layout->Release()


	// Create vertex buffer

	vertex_stride: u32
	vertex_offset: u32
	{
		vertex_data := addShapeToRealData(inputs[:])

		//dx11不允许0上传,所以随便分配一下.
		if len(vertex_data) == 0 {
			vertex_data = make([]f32, 10)
		}
		defer delete(vertex_data)

		vertex_count := u32(len(vertex_data) / 6)

		vertex_stride = size_of(f32) * 6
		vertex_offset = 0

		vertex_buffer_desc := d3d11.BUFFER_DESC {
			ByteWidth      = u32(size_of(f32) * 10000),
			Usage          = .DYNAMIC,
			BindFlags      = {.VERTEX_BUFFER},
			CPUAccessFlags = {.WRITE},
		}

		vertex_subresource_data := d3d11.SUBRESOURCE_DATA {
			pSysMem = raw_data(vertex_data),
		}

		res := device->CreateBuffer(
			pDesc = &vertex_buffer_desc,
			pInitialData = &vertex_subresource_data,
			ppBuffer = &vertex_buffer,
		)
		assert_messagebox(res, "Create VertexBuffer failed")
	}
	defer vertex_buffer->Release()


	// Game loop
	is_running := true
	for is_running {


		duration := time.stopwatch_duration(sw)
		dt := cast(f32)time.duration_seconds(duration)


		msg: win.MSG
		for win.PeekMessageW(&msg, nil, 0, 0, win.PM_REMOVE) {
			if msg.message == win.WM_QUIT {
				is_running = false
			}
			win.TranslateMessage(&msg)
			win.DispatchMessageW(&msg)
		}


		bg_color := [4]f32{0, 0.4, 0.6, 1}
		device_context->ClearRenderTargetView(framebuffer_view, &bg_color)

		window_rect: win.RECT
		win.GetClientRect(hWnd, &window_rect)
		viewport := d3d11.VIEWPORT {
			TopLeftX = 0,
			TopLeftY = 0,
			Width    = f32(window_rect.right - window_rect.left),
			Height   = f32(window_rect.bottom - window_rect.top),
			MinDepth = 0,
			MaxDepth = 1,
		}

		device_context->RSSetViewports(1, &viewport)
		device_context->OMSetRenderTargets(1, &framebuffer_view, nil)

		device_context->IASetPrimitiveTopology(.TRIANGLELIST)
		device_context->IASetInputLayout(input_layout)

		device_context->VSSetShader(vertex_shader, nil, 0)
		device_context->PSSetShader(pixel_shader, nil, 0)

		device_context->IASetVertexBuffers(0, 1, &vertex_buffer, &vertex_stride, &vertex_offset)


		// if len(vertex_data) > 3 {
		// 	for i := 0; i < len(vertex_data); i += 6 {
		// 		vertex_data[i + 1] += 0 // 0.00031
		// 	}
		// }
		// vertex_count = u32(len(vertex_data) / 6)


		// mapped: d3d11.MAPPED_SUBRESOURCE
		// device_context->Map(vertex_buffer, 0, .WRITE_DISCARD, {}, &mapped)
		// dst := ([^]f32)(mapped.pData)
		// for i in 0 ..< len(vertex_data) {
		// 	dst[i] = vertex_data[i]
		// }
		// device_context->Unmap(vertex_buffer, 0)


		device_context->Draw(vertex_count, 0)

		swapchain->Present(1, {})
	}
}
