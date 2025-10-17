package chip8

import "core:io"
import "core:os"
import "core:time"


main :: proc () {
    platform, ok := platform_init()
    if !ok {
        return
    }
    defer platform_destroy(&platform)

    computer := computer_new(CHIP8_QUIRKS)

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

    for !platform.should_quit {
        platform_handle_events(&platform, &computer)

        computer_process(&computer)

        platform_render(&platform, computer.display[:])

        time.sleep(time.Millisecond * 16)
    }
}
