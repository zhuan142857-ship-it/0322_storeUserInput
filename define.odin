package a

Position :: struct {
	x, y: f32,
}

Color :: struct {
	r, g, b, a: f32,
}

Colors :: struct {
	c825, c333, c285: Color,
}

Shape :: enum {
	//	noShapeInChoice,
	square,
	triangle,
}

Camera :: struct {
	offset: Position,
	scale:  f32, //先用scale,因为这种抽象,没有透视,当然就没有高度,也就和现实没什么关系,所以就用scale
	//先随便规定,scale=2就是看的范围更大,物体更小,相机高度更高
}

UserInput :: struct {
	position: Position,
	shape:    Shape,
}
