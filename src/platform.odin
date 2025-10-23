package chip8

import "core:fmt"
import "core:math"
import "core:strings"
import "core:time"
import "vendor:sdl3"

import im "shared:imgui"
import im_sdl "shared:imgui/imgui_impl_sdl3"
import im_sdlr "shared:imgui/imgui_impl_sdlrenderer3"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

EMULATOR_WIDTH :: 960
EMULATOR_HEIGHT :: 480

AUDIO_SAMPLE_RATE :: 8000
AUDIO_AMPLITUDE :: .75
AUDIO_FREQUENCY :: 880.0

Platform :: struct {
	window:       ^sdl3.Window,
	renderer:     ^sdl3.Renderer,
	texture:      ^sdl3.Texture,
	audio_stream: ^sdl3.AudioStream,
	should_quit:  bool,
	is_paused:    bool,
	color_scheme: Color_Scheme,
}

Platform_Config :: struct {
	color_scheme: Color_Scheme_Type,
}

platform_init :: proc(config: Platform_Config) -> (p: Platform, ok: bool) {
	if !sdl3.Init({.VIDEO, .EVENTS, .AUDIO}) {
		fmt.eprintfln("Failed to initialize SDL3: %v", sdl3.GetError())
		return {}, false
	}
	defer if !ok {sdl3.Quit()}

	p.window = sdl3.CreateWindow("[O] CHIP8", WINDOW_WIDTH, WINDOW_HEIGHT, {})
	if p.window == nil {
		fmt.eprintfln("Failed to create window: %v", sdl3.GetError())
		return {}, false
	}
	defer if !ok {sdl3.DestroyWindow(p.window)}

	p.renderer = sdl3.CreateRenderer(p.window, nil)
	if p.renderer == nil {
		fmt.eprintfln("Failed to create renderer: %v", sdl3.GetError())
		return {}, false
	}
	defer if !ok {sdl3.DestroyRenderer(p.renderer)}

	p.texture = sdl3.CreateTexture(p.renderer, .RGBA8888, .STREAMING, 64, 32)
	if p.texture == nil {
		fmt.eprintfln("Failed to create texture: %v", sdl3.GetError())
		return {}, false
	}
	defer if !ok {sdl3.DestroyTexture(p.texture)}

	sdl3.SetTextureScaleMode(p.texture, .NEAREST)

	audio_spec := sdl3.AudioSpec {
		channels = 1,
		format   = .F32,
		freq     = AUDIO_SAMPLE_RATE,
	}
	p.audio_stream = sdl3.OpenAudioDeviceStream(
		sdl3.AUDIO_DEVICE_DEFAULT_PLAYBACK,
		&audio_spec,
		nil,
		nil,
	)
	if p.audio_stream == nil {
		fmt.eprintfln("Failed to create audio stream: %v", sdl3.GetError())
		return {}, false
	}
	sdl3.ResumeAudioStreamDevice(p.audio_stream)

	im.CHECKVERSION()
	im.CreateContext()

	im_sdl.InitForSDLRenderer(p.window, p.renderer)
	im_sdlr.Init(p.renderer)

	p.color_scheme = BUILTIN_COLORSCHEMES[config.color_scheme]

	return p, true
}

platform_run :: proc(p: ^Platform, c: ^Computer) {
	for !p.should_quit {
		platform_handle_events(p, c)

		if !p.is_paused {
			computer_process(c)

			platform_play_sound(p, c)
		}
		platform_render(p, c)

		time.sleep(time.Millisecond * 16)
	}
}

platform_destroy :: proc(p: ^Platform) {
	im_sdlr.Shutdown()
	im_sdl.Shutdown()
	im.DestroyContext()

	if p.audio_stream != nil {
		sdl3.PauseAudioStreamDevice(p.audio_stream)
		sdl3.DestroyAudioStream(p.audio_stream)
	}

	if p.texture != nil {sdl3.DestroyTexture(p.texture)}
	if p.renderer != nil {sdl3.DestroyRenderer(p.renderer)}
	if p.window != nil {sdl3.DestroyWindow(p.window)}

	sdl3.Quit()
}

platform_handle_events :: proc(p: ^Platform, c: ^Computer) {
	e: sdl3.Event
	for sdl3.PollEvent(&e) {
		im_sdl.ProcessEvent(&e)

		#partial switch e.type {
		case .QUIT:
			p.should_quit = true
		case .KEY_DOWN:
			platform_handle_key(p, c, e.key.scancode, 1)
		case .KEY_UP:
			platform_handle_key(p, c, e.key.scancode, 0)
		}
	}
}

platform_handle_key :: proc(p: ^Platform, c: ^Computer, scancode: sdl3.Scancode, value: u8) {
	#partial switch scancode {
	case ._1:
		c.keys[0x1] = value
	case ._2:
		c.keys[0x2] = value
	case ._3:
		c.keys[0x3] = value
	case ._4:
		c.keys[0xC] = value
	case .Q:
		c.keys[0x4] = value
	case .W:
		c.keys[0x5] = value
	case .E:
		c.keys[0x6] = value
	case .R:
		c.keys[0xD] = value
	case .A:
		c.keys[0x7] = value
	case .S:
		c.keys[0x8] = value
	case .D:
		c.keys[0x9] = value
	case .F:
		c.keys[0xE] = value
	case .Z:
		c.keys[0xA] = value
	case .X:
		c.keys[0x0] = value
	case .C:
		c.keys[0xB] = value
	case .V:
		c.keys[0xF] = value
	case .P:
		if value == 0 {
			p.is_paused = !p.is_paused
		}
	}
}

platform_render :: proc(p: ^Platform, c: ^Computer) {
	draw_computer_display_to_texture(p.texture, c.display[:], p.color_scheme)

	// Start ImGui frame
	im_sdlr.NewFrame()
	im_sdl.NewFrame()
	im.NewFrame()

	MENU_BAR_HEIGHT :: 0


	PADDING :: 10
	PANE_WIDTH :: (WINDOW_WIDTH - EMULATOR_WIDTH - PADDING * 2)
	PANE_HEIGHT :: WINDOW_HEIGHT - MENU_BAR_HEIGHT

	// Emulator viewport window
	VIEWPORT_X :: PADDING
	VIEWPORT_Y :: (WINDOW_HEIGHT - MENU_BAR_HEIGHT - EMULATOR_HEIGHT) / 2
	{
		im.SetNextWindowPos({VIEWPORT_X, VIEWPORT_Y})
		im.SetNextWindowSize({EMULATOR_WIDTH, EMULATOR_HEIGHT})

		im.PushStyleVarImVec2(.WindowPadding, {0, 0})
		im.Begin(
			"CHIP-8 Display",
			nil,
			{.NoMove, .NoResize, .NoCollapse, .NoTitleBar, .NoScrollbar},
		)

		// Display the emulator texture as an image in ImGui
		im.Image(u64(uintptr(p.texture)), {EMULATOR_WIDTH, EMULATOR_HEIGHT})

		im.PopStyleVar(1)
		im.End()
	}

	// Right sidebar
	RIGHT_PANE_X :: WINDOW_WIDTH - PANE_WIDTH
	RIGHT_PANE_Y :: MENU_BAR_HEIGHT
	{
		im.SetNextWindowPos({RIGHT_PANE_X, RIGHT_PANE_Y})
		im.SetNextWindowSize({PANE_WIDTH, PANE_HEIGHT})
		im.Begin("Info", nil, {.NoMove, .NoResize, .NoCollapse, .NoTitleBar})

		// Button styling constants
		BUTTON_WIDTH :: 80
		BUTTON_HEIGHT :: 30
		SPACING :: 5

		DOUBLE_BUTTON_WIDTH :: BUTTON_WIDTH * 2 + SPACING
		DOUBLE_BUTTON_CENTER_X :: (PANE_WIDTH - DOUBLE_BUTTON_WIDTH) * 0.5

		im.Spacing()

		// Centered pause/resume button
		{
			im.SetCursorPosX(DOUBLE_BUTTON_CENTER_X)

			if im.Button(p.is_paused ? "Resume" : "Pause", {DOUBLE_BUTTON_WIDTH, BUTTON_HEIGHT}) {
				p.is_paused = !p.is_paused
			}
		}

		im.Spacing()
		im.Separator()
		im.Spacing()

		// Emulation Speed Control
		{
			// Display current speed as a multiplier
			speed_multiplier := f32(c.speed) / f32(DEFAULT_COMPUTER_CONFIG.clock_speed)
			speed_text := fmt.tprintf("%.2fx (%d Hz)", speed_multiplier, c.speed)
			s := strings.clone_to_cstring(speed_text, allocator = context.temp_allocator)

			text_width := im.CalcTextSize(s).x
			im.SetCursorPosX((PANE_WIDTH - text_width) * 0.5)
			im.Text(s)

			im.Spacing()

			im.SetCursorPosX(DOUBLE_BUTTON_CENTER_X)

			MIN_SPEED :: DEFAULT_COMPUTER_CONFIG.clock_speed / 2 // 0.5x
			MAX_SPEED :: DEFAULT_COMPUTER_CONFIG.clock_speed * 3 // 3.0x
			SPEED_STEP :: DEFAULT_COMPUTER_CONFIG.clock_speed / 4 // 0.25x

			// Slow down button
			if im.Button("<<", {BUTTON_WIDTH, BUTTON_HEIGHT}) {
				c.speed = max(MIN_SPEED, c.speed - SPEED_STEP)
			}

			im.SameLine()
			im.SetCursorPosX(DOUBLE_BUTTON_CENTER_X + BUTTON_WIDTH + SPACING)

			// Speed up button
			if im.Button(">>", {BUTTON_WIDTH, BUTTON_HEIGHT}) {
				c.speed = min(MAX_SPEED, c.speed + SPEED_STEP)
			}
		}

		im.Spacing()
		im.Separator()
		im.Spacing()

		im.End()
	}

	im.Render()

	sdl3.SetRenderDrawColorFloat(p.renderer, 0.1, 0.1, 0.1, 1)
	sdl3.RenderClear(p.renderer)

	// Render ImGui (which includes our texture as an image)
	im_sdlr.RenderDrawData(im.GetDrawData(), p.renderer)

	sdl3.RenderPresent(p.renderer)

	free_all(context.temp_allocator)
}

platform_play_sound :: proc(p: ^Platform, c: ^Computer) {
	if c.sound_timer == 0 {
		sdl3.ClearAudioStream(p.audio_stream)
		return
	}

	samples: [256]f32
	generate_audio_samples(samples[:])
	sdl3.PutAudioStreamData(p.audio_stream, raw_data(samples[:]), size_of(samples))
}

generate_audio_samples :: proc(buffer: []f32) {
	@(static) phase: f32 = 0

	for i in 0 ..< len(buffer) {
		buffer[i] = math.sin_f32(phase) * AUDIO_AMPLITUDE
		phase += 2.0 * math.PI * AUDIO_FREQUENCY / AUDIO_SAMPLE_RATE
		if phase > 2.0 * math.PI {
			phase -= 2.0 * math.PI
		}
	}
}

draw_computer_display_to_texture :: proc(
	tex: ^sdl3.Texture,
	display: []u8,
	color_scheme: Color_Scheme,
) {
	pitch: i32 = 0
	pixels: rawptr

	sdl3.LockTexture(tex, nil, &pixels, &pitch)
	buffer := ([^]u32)(pixels)[:64 * 32]
	for pixel, idx in display {
		if pixel == 1 {
			buffer[idx] = color_scheme.foreground
		} else {
			buffer[idx] = color_scheme.background
		}
	}
	sdl3.UnlockTexture(tex)
}
