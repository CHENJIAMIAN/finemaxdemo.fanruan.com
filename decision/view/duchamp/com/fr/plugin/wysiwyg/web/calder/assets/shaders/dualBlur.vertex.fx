// Attributes
attribute vec2 position;

// Output
varying vec2 uvcoordsvar;

const vec2 madd = vec2(0.5, 0.5);


#define CUSTOM_VERTEX_DEFINITIONS

void main(void) {

#define CUSTOM_VERTEX_MAIN_BEGIN

	uvcoordsvar = position * madd + madd;
	gl_Position = vec4(position, 0.0, 1.0);

#define CUSTOM_VERTEX_MAIN_END
}