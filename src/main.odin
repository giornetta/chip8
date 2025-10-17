package chip8

import "core:flags"
import "core:io"
import "core:os"
import "core:time"

Config :: struct {
    clock_speed: i64 `usage:"CPU clock speed in Hz" default:"700"`,
    rom_path: os.Handle `args:"pos=0,required,file=r" usage:"path of the ROM to execute"`,
}

main :: proc () {
    config : Config
    if err := flags.parse(&config, os.args[1:], .Unix); err != nil {
        flags.write_usage(os.stream_from_handle(os.stderr), typeid_of(Config), os.args[0], .Unix)
        return
    }

    platform, ok := platform_init()
    if !ok {
        return
    }
    defer platform_destroy(&platform)

    computer := computer_new(CHIP8_QUIRKS)

    reader := io.to_reader(os.stream_from_handle(config.rom_path))
    computer_load(&computer, reader)

    for !platform.should_quit {
        platform_handle_events(&platform, &computer)

        computer_process(&computer)

        platform_render(&platform, computer.display[:])

        time.sleep(time.Millisecond * 16)
    }
}
