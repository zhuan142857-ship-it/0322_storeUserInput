package a
import "core:sys/posix"
import win "core:sys/windows"
import "core:time"
import "vendor:directx/d3d11"

WINDOW_NAME :: "..."

WIDTH :: 3840
HEIGHT :: 2160

colors := Colors {
	c285 = Color{0.2, 0.8, 0.5, 1},
	c333 = Color{0.3, 0.3, 0.3, 1},
	c825 = Color{0.8, 0.2, 0.5, 1},
}

vertex_buffer: ^d3d11.IBuffer
device_context: ^d3d11.IDeviceContext

hWnd: win.HWND
hInstance := win.HINSTANCE(win.GetModuleHandleW(nil))

vertex_data: [dynamic]f32
vertex_count: u32

shape := Shape.triangle

sw: time.Stopwatch

UserInput :: struct {
	position: Position,
	shape:    Shape,
}

inputs: [dynamic]UserInput

camera := Camera{Position{500, 500}, 5}
