package chip8

import "core:fmt"
import "vendor:sdl3"

WINDOW_WIDTH :: 960
WINDOW_HEIGHT :: 480

Platform :: struct {
    window: ^sdl3.Window,
    renderer: ^sdl3.Renderer,
    texture: ^sdl3.Texture,

    render_buffer: []u32,
    
    should_quit: bool,
}

platform_init :: proc() -> (p: Platform, ok: bool) {
    if !sdl3.Init({.VIDEO, .EVENTS}) {
        fmt.eprintln("Failed to initialize SDL3")
        return {}, false
    }
    defer if !ok { sdl3.Quit() }

    p.window = sdl3.CreateWindow("[O] CHIP8", WINDOW_WIDTH, WINDOW_HEIGHT, {})
    if p.window == nil {
        fmt.eprintln("Failed to create window")
        return {}, false
    }
    defer if !ok { sdl3.DestroyWindow(p.window) }

    p.renderer = sdl3.CreateRenderer(p.window, nil)
    if p.renderer == nil {
        fmt.eprintln("Failed to create renderer")
        return {}, false
    }
    defer if !ok { sdl3.DestroyRenderer(p.renderer) }

    sdl3.SetRenderLogicalPresentation(p.renderer, 64, 32, .LETTERBOX)

    p.texture = sdl3.CreateTexture(p.renderer, .RGBA8888, .STREAMING, 64, 32)
    if p.texture == nil {
        fmt.eprintln("Failed to create texture")
        return {}, false
    }
    defer if !ok { sdl3.DestroyTexture(p.texture) }

    sdl3.SetTextureScaleMode(p.texture, .NEAREST)

    p.render_buffer = make([]u32, 64*32)

    p.should_quit = false

    return p, true
}

platform_destroy :: proc(p: ^Platform) {
    if p.render_buffer != nil { delete(p.render_buffer) }

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
                platform_handle_key(c, e.key.scancode, 1)
            case .KEY_UP:
                platform_handle_key(c, e.key.scancode, 0)
        }
    }
}

platform_handle_key :: proc(c: ^Computer, scancode: sdl3.Scancode, value: u8) {
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
    }
}

platform_render :: proc(p: ^Platform, display: []u8) {
    sdl3.RenderClear(p.renderer)

    pitch : i32 = 0
    
    sdl3.LockTexture(p.texture, nil, cast(^rawptr) &p.render_buffer, &pitch)
    for pixel, idx in display {
        if pixel == 1 {
            p.render_buffer[idx] = 0xFFFFFFFF
        } else {
            p.render_buffer[idx] = 0x000000FF
        }
    }
    sdl3.UnlockTexture(p.texture)

    sdl3.RenderTexture(p.renderer, p.texture, nil, nil)
    sdl3.RenderPresent(p.renderer)
}
