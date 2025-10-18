# CHIP-8 Emulator

A CHIP-8 emulator written in [Odin](https://odin-lang.org/) with SDL3 for graphics rendering.

## About CHIP-8

CHIP-8 is an interpreted programming language developed in the mid-1970s. It was designed to make game programming easier for the COSMAC VIP and Telmac 1800 8-bit microcomputers. CHIP-8 programs are run on a virtual machine with:

- 4KB of memory
- 16 general-purpose 8-bit registers (V0-VF)
- A 16-bit index register
- A 64x32 pixel monochrome display
- A 16-key hexadecimal keypad
- Delay and sound timers

## Features

- Full CHIP-8 instruction set implementation
- SDL3-based graphics rendering at 64x32 resolution
- Configurable quirks system for compatibility with different CHIP-8 implementations
- 60Hz timer update rate
- Configurable CPU speed (default: 700 instructions per second)
- Multiple built-in color schemes

## Prerequisites

- [Odin compiler](https://odin-lang.org/)
- SDL3 development libraries

## Building

```bash
odin build src -out:chip8
```

## Usage

Run the emulator with a CHIP-8 ROM file:

```bash
./chip8 path/to/rom.ch8
```

Use `./chip8 --help` to see available command-line options for configuring the emulator.

### Keyboard Layout

The CHIP-8 keypad is mapped to your keyboard as follows:

```
CHIP-8 Keypad          Keyboard
┌───┬───┬───┬───┐      ┌───┬───┬───┬───┐
│ 1 │ 2 │ 3 │ C │      │ 1 │ 2 │ 3 │ 4 │
├───┼───┼───┼───┤      ├───┼───┼───┼───┤
│ 4 │ 5 │ 6 │ D │  →   │ Q │ W │ E │ R │
├───┼───┼───┼───┤      ├───┼───┼───┼───┤
│ 7 │ 8 │ 9 │ E │      │ A │ S │ D │ F │
├───┼───┼───┼───┤      ├───┼───┼───┼───┤
│ A │ 0 │ B │ F │      │ Z │ X │ C │ V │
└───┴───┴───┴───┘      └───┴───┴───┴───┘
```

## Technical Details

### Memory Map

```
0x000-0x1FF  Reserved (interpreter area)
0x050-0x0A0  Font data (16 characters × 5 bytes)
0x200-0xFFF  Program ROM and RAM
```

### Display

- Resolution: 64×32 pixels
- Format: Monochrome
- Rendering: XOR-based sprite drawing
- Window size: 960×480 (15× upscaling)

### Timers

Both delay and sound timers decrement at 60Hz when non-zero. The sound timer should trigger audio output while greater than zero.

## ROMs

CHIP-8 ROM files typically have the `.ch8` extension. You can find public domain ROMs and test programs online. The emulator loads ROMs starting at memory address 0x200.

## References

- [Tobias V. Langhoff's CHIP-8 Guide](https://tobiasvl.github.io/blog/write-a-chip-8-emulator/)
- [Cowgod's CHIP-8 Technical Reference](http://devernay.free.fr/hacks/chip8/C8TECH10.HTM)
- [Timendus' CHIP-8 Test Suite](https://github.com/Timendus/chip8-test-suite)
- [CHIP-8 Wikipedia](https://en.wikipedia.org/wiki/CHIP-8)
- [Odin Programming Language](https://odin-lang.org/)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.