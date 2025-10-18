package chip8

import "core:flags"
import "core:io"
import "core:os"

Config :: struct {
    clock_speed: i64 `usage:"CPU clock speed in Hz (default: 700)"`,
    color_scheme: Color_Scheme_Type `usage:"Name of the colorscheme to use (Classic, Amber, Green, Blue) (default: Classic)"`,
    rom_path: os.Handle `args:"pos=0,required,file=r" usage:"path of the ROM to execute"`,
}

Default_Config :: Config{
    clock_speed = 700,
    color_scheme = .Classic,
}

main :: proc () {
    config := Default_Config
    if err := flags.parse(&config, os.args[1:], .Unix); err != nil {
        flags.write_usage(os.stream_from_handle(os.stderr), typeid_of(Config), os.args[0], .Unix)
        return
    }
    defer os.close(config.rom_path)

    platform, ok := platform_init(Platform_Config{
        color_scheme = config.color_scheme
    })
    if !ok {
        return
    }
    defer platform_destroy(&platform)

    computer := computer_new(Computer_Config{
        clock_speed = config.clock_speed,
        quirks = CHIP8_QUIRKS,
    })

    reader := io.to_reader(os.stream_from_handle(config.rom_path))
    computer_load(&computer, reader)

    platform_run(&platform, &computer)
}
