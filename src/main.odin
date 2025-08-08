package chip8

import "core:io"
import "core:os"
import "core:fmt"
import "core:time"

import "vendor:sdl3"

WINDOW_WIDTH :: 960
WINDOW_HEIGHT :: 480

main :: proc () {
    ok := sdl3.Init({.VIDEO, .EVENTS}); assert(ok)
    defer sdl3.Quit()

    window := sdl3.CreateWindow("[O] CHIP8", WINDOW_WIDTH, WINDOW_HEIGHT, {}); assert(window != nil)
    defer sdl3.DestroyWindow(window)

    renderer := sdl3.CreateRenderer(window, nil); assert(renderer != nil)
    sdl3.SetRenderLogicalPresentation(renderer, 64, 32, .LETTERBOX)
    defer sdl3.DestroyRenderer(renderer)

    texture := sdl3.CreateTexture(renderer, .RGBA8888, .STREAMING, 64, 32); assert(texture != nil)
    sdl3.SetTextureScaleMode(texture, .NEAREST)
    defer sdl3.DestroyTexture(texture)

    computer := computer_new()

    if len(os.args) != 2 {
        return
    }
    filename := os.args[1]

    file, err := os.open(filename)
    if err != nil {
        return
    }
    defer os.close(file)

    reader := io.to_reader(os.stream_from_handle(file))
    computer_load(&computer, reader)

    fmt.printf("Loaded program\n")

    done := false
    for !done {
        e: sdl3.Event
        if sdl3.PollEvent(&e) {
            #partial switch e.type {
                case .QUIT:
                    done = true
                case .KEY_DOWN:
                    handle_key(&computer, e.key.scancode, 1)
                case .KEY_UP:
                    handle_key(&computer, e.key.scancode, 0)
            }
        }
        
        computer_cycle(&computer)

        sdl3.RenderClear(renderer)

        bytes := make([^]u32, 64*32)
        pitch : i32 = 0
        sdl3.LockTexture(texture, nil, cast(^rawptr) &bytes, &pitch)
        for pixel, idx in computer.display {
            if pixel == 1 {
                bytes[idx] = 0xFFFFFFFF
            } else {
                bytes[idx] = 0x000000FF
            }
        }
        sdl3.UnlockTexture(texture)

        sdl3.RenderTexture(renderer, texture, nil, nil)
        sdl3.RenderPresent(renderer)

        time.sleep(time.Millisecond * 16)
    }
}

handle_key :: proc(c: ^Computer, scancode: sdl3.Scancode, value: u8) {
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