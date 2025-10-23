package chip8

Color_Scheme :: struct {
	foreground: u32,
	background: u32,
}

Color_Scheme_Type :: enum {
	Classic,
	Amber,
	Green,
	Blue,
}

BUILTIN_COLORSCHEMES := [Color_Scheme_Type]Color_Scheme {
	.Classic = {foreground = 0xFFFFFFFF, background = 0x000000FF},
	.Amber = {foreground = 0xFFB000FF, background = 0x000000FF},
	.Green = {foreground = 0x33FF33FF, background = 0x001100FF},
	.Blue = {foreground = 0x6495EDFF, background = 0x000033FF},
}
