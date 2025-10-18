package chip8

import "core:time"
import "core:fmt"
import "core:math"
import "vendor:sdl3"

WINDOW_WIDTH :: 960
WINDOW_HEIGHT :: 480

AUDIO_SAMPLE_RATE :: 8000
AUDIO_AMPLITUDE :: .75
AUDIO_FREQUENCY :: 880.0

Platform :: struct {
    window: ^sdl3.Window,
    renderer: ^sdl3.Renderer,
    texture: ^sdl3.Texture,
    audio_stream: ^sdl3.AudioStream,

    should_quit: bool,
    is_paused: bool,

    color_scheme: Color_Scheme,
}

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
    .Classic = {foreground = 0xFFFFFFFF, background = 0x000000FF },
    .Amber   = {foreground = 0xFFB000FF, background = 0x000000FF},
    .Green = {foreground = 0x33FF33FF, background = 0x001100FF},
    .Blue           = {foreground = 0x6495EDFF, background = 0x000033FF},
}

Platform_Config :: struct {
    color_scheme: Color_Scheme_Type,
}

platform_init :: proc(config: Platform_Config) -> (p: Platform, ok: bool) {
    if !sdl3.Init({.VIDEO, .EVENTS, .AUDIO}) {
        fmt.eprintfln("Failed to initialize SDL3: %v", sdl3.GetError())
        return {}, false
    }
    defer if !ok { sdl3.Quit() }

    p.window = sdl3.CreateWindow("[O] CHIP8", WINDOW_WIDTH, WINDOW_HEIGHT, {})
    if p.window == nil {
        fmt.eprintfln("Failed to create window: %v", sdl3.GetError())
        return {}, false
    }
    defer if !ok { sdl3.DestroyWindow(p.window) }

    p.renderer = sdl3.CreateRenderer(p.window, nil)
    if p.renderer == nil {
        fmt.eprintfln("Failed to create renderer: %v", sdl3.GetError())
        return {}, false
    }
    defer if !ok { sdl3.DestroyRenderer(p.renderer) }

    sdl3.SetRenderLogicalPresentation(p.renderer, 64, 32, .LETTERBOX)

    p.texture = sdl3.CreateTexture(p.renderer, .RGBA8888, .STREAMING, 64, 32)
    if p.texture == nil {
        fmt.eprintfln("Failed to create texture: %v", sdl3.GetError())
        return {}, false
    }
    defer if !ok { sdl3.DestroyTexture(p.texture) }

    sdl3.SetTextureScaleMode(p.texture, .NEAREST)

    audio_spec := sdl3.AudioSpec{
        channels = 1,
        format = .F32,
        freq = AUDIO_SAMPLE_RATE,
    }
    p.audio_stream = sdl3.OpenAudioDeviceStream(sdl3.AUDIO_DEVICE_DEFAULT_PLAYBACK, &audio_spec, nil, nil)
    if p.audio_stream == nil {
        fmt.eprintfln("Failed to create audio stream: %v", sdl3.GetError())
        return {}, false
    }
    sdl3.ResumeAudioStreamDevice(p.audio_stream)

    p.color_scheme = BUILTIN_COLORSCHEMES[config.color_scheme]

    return p, true
}

platform_run :: proc(p: ^Platform, c: ^Computer) {
    for !p.should_quit {
        platform_handle_events(p, c)

        if !p.is_paused {
            computer_process(c)

            platform_render(p, c.display[:])
            platform_play_sound(p, c)
        }

        time.sleep(time.Millisecond * 16)
    }
}

platform_destroy :: proc(p: ^Platform) {
    if p.audio_stream != nil {
        sdl3.PauseAudioStreamDevice(p.audio_stream)
        sdl3.DestroyAudioStream(p.audio_stream)
    }

    if p.texture != nil { sdl3.DestroyTexture(p.texture) }
    if p.renderer != nil { sdl3.DestroyRenderer(p.renderer) }
    if p.window != nil { sdl3.DestroyWindow(p.window) }

    sdl3.Quit()
}

platform_handle_events :: proc(p: ^Platform, c: ^Computer) {
    e: sdl3.Event
    for sdl3.PollEvent(&e) {
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

platform_render :: proc(p: ^Platform, display: []u8) {
    sdl3.RenderClear(p.renderer)

    pitch : i32 = 0
    pixels: rawptr
    
    sdl3.LockTexture(p.texture, nil, &pixels, &pitch)
    buffer := ([^]u32)(pixels)[:64*32]
    for pixel, idx in display {
        if pixel == 1 {
            buffer[idx] = p.color_scheme.foreground
        } else {
            buffer[idx] = p.color_scheme.background
        }
    }
    sdl3.UnlockTexture(p.texture)

    sdl3.RenderTexture(p.renderer, p.texture, nil, nil)
    sdl3.RenderPresent(p.renderer)
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
    @static phase: f32 = 0

    for i in 0..<len(buffer) {
        buffer[i] = math.sin_f32(phase) * AUDIO_AMPLITUDE
        phase += 2.0 * math.PI * AUDIO_FREQUENCY / AUDIO_SAMPLE_RATE
        if phase > 2.0 * math.PI {
            phase -= 2.0 * math.PI
        }
    }
}