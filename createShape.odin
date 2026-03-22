package a

import "core:fmt"
import "core:slice"


addShapeToRealData :: proc(inputs: []UserInput) -> []f32 {

	vertex_data: [dynamic]f32
	for v in inputs {

		verticesSlice: []Position
		defer delete(verticesSlice)

		if v.shape == Shape.triangle {
			vertices := triangleShape(v.position)
			verticesSlice = slice.clone(vertices[:])
		}
		if v.shape == Shape.square {
			vertices := rectangleShape(v.position)
			verticesSlice = slice.clone(vertices[:])
		}

		vertex_camera := make([]Position, len(verticesSlice), context.temp_allocator)
		for v, i in verticesSlice {
			vertex_camera[i].x = (v.x - camera.offset.x) / camera.scale
			vertex_camera[i].y = (v.y - camera.offset.y) / camera.scale
		}


		vertex_NDC := make([]Position, len(vertex_camera), context.temp_allocator)
		for v, i in vertex_camera {
			vertex_NDC[i].x = v.x / WIDTH * 2 - 1
			vertex_NDC[i].y = v.y / HEIGHT * 2 - 1
		}

		c := colors.c825
		c4 := [4]f32{c.r, c.g, c.b, c.a}
		vertex_final := make([]f32, len(vertex_NDC) * 6, context.temp_allocator)
		for v, i in vertex_NDC {
			vertex_final[6 * i] = v.x
			vertex_final[6 * i + 1] = v.y
			copy(vertex_final[6 * i + 2:6 * i + 6], c4[:])
		}

		append(&vertex_data, ..vertex_final[:])

	}

	//vvv = vertex_data[:]
	//这里有两个原因不能delete
	//1:在函数外面delete,因为外面会用到我的返回值
	//2:虽然多了一层倒手(dynamic-->>>>slice),但是指向的是同一个地方
	//如果这里delete,那么就是"双重"delete
	return vertex_data[:]
}
