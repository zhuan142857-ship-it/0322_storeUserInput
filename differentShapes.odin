package a

//鼠标点击,创建等腰直角三角形顶点并绕序
triangleShape :: proc(pos: Position, sideLength: f32 = 100) -> (vertices: [3]Position) {
	vertices[0] = Position{pos.x, pos.y + sideLength}
	vertices[1] = Position{pos.x + sideLength, pos.y}
	vertices[2] = Position{pos.x - sideLength, pos.y}
	return
}

rectangleShape :: proc(pos: Position, sideLength: f32 = 50) -> (vertices: [6]Position) {
	vertices[0] = Position{pos.x - sideLength, pos.y + sideLength}
	vertices[1] = Position{pos.x + sideLength, pos.y + sideLength}
	vertices[2] = Position{pos.x - sideLength, pos.y - sideLength}
	vertices[3] = Position{pos.x - sideLength, pos.y - sideLength}
	vertices[4] = Position{pos.x + sideLength, pos.y + sideLength}
	vertices[5] = Position{pos.x + sideLength, pos.y - sideLength}
	return
}
