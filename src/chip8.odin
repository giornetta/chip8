package chip8

import "core:time"
import "core:io"
import "core:fmt"
import "core:math/rand"

FONT := [5*16]u8  {
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80  // F
}

FONT_ADDRESS :: 0x50
FONT_CHARACTER_SIZE :: 5

BASE_PC_ADDRESS :: 0x200

DISPLAY_WIDTH :: 64
DISPLAY_HEIGHT :: 32

Computer :: struct {
    // CHIP-8 has a 4KB RAM, from 0x000 to 0xFFF
    // Sections:
    // - 0x000:0x1FF -> the original interpreter was located here, it should not be used by any program.
    // - 0x200       -> beginning of most programs.
    memory: [4096]u8,
    // PC is used to store the currently executing address.
    program_counter: u16,

    // CHIP-8 uses a 64x32 px monochrome display with the following format:
    // --------------------------
    // | (0, 0)         (63, 0) |
    // |                        |
    // | (0, 31)       (63, 31) |
    // --------------------------
    display: [DISPLAY_WIDTH * DISPLAY_HEIGHT]u8,

    // CHIP-8 has 16 general purpose 8-bit registers, usually referred as V0:VF.
    registers: [16]u8,
    // The index register is generally used to store memory addresses.
    index_register: u16,
    // The delay and sound timers should be decremented at a rate of 60Hz when they're non-zero.
    delay_timer: u8,
    sound_timer: u8, // The computer should "beep" as long as this is > 0.

    // The stack is used to store the address that the interpreter should return to when finished with a subroutine.
    // CHIP-8 allows for up to 16 levels of nested subroutines.
    stack: [16]u16,
    stack_pointer: u16,

    // CHIP-8 computers had a 16-key exadecimal keypad with the following layout:
    // -----------------
    // | 1 | 2 | 3 | C |
    // | 4 | 5 | 6 | D |
    // | 7 | 8 | 9 | E |
    // | A | 0 | B | F |
    // -----------------
    keys: [16]u8,

    frame_time: f64,
    // Speed represents how many instructions to execute in a second.
    speed: i64,
    clock: i64,
    cycles: i64
}

computer_new :: proc() -> Computer {
    c := Computer{
        program_counter = BASE_PC_ADDRESS,
        speed = 700,
        clock = time.to_unix_nanoseconds(time.now())
    }

    for i in 0..<len(FONT) {
        c.memory[FONT_ADDRESS+i] = FONT[i]
    }

    return c
}

computer_load :: proc(c: ^Computer, r: io.Reader) {
    c.program_counter = BASE_PC_ADDRESS

    buffer: [1]u8
    i := 0
    for {
        n, err := io.read(r, buffer[:])
        if err != nil {
            if err == io.Error.EOF {
                break
            }

            break
        }

        if n > 0 {
            fmt.printf("Read byte: %#02x\n", buffer[0])
            c.memory[BASE_PC_ADDRESS+i] = buffer[0]
            i +=1
        }
    }
}

computer_process :: proc(c: ^Computer) {
    now := time.to_unix_nanoseconds(time.now())
    cycles := (now - c.clock) * c.speed / 1_000_000_000

    for c.cycles < cycles {
        computer_cycle(c)
    }
}

computer_cycle :: proc(c: ^Computer) {
    instruction := computer_fetch(c)
    operation := computer_decode(c, instruction)

    fmt.printf("Instruction: %#04x, Operation %v\n", instruction, operation)

    computer_execute(c, operation)
    c.cycles += 1

    if c.cycles % c.speed == 0 {
        if c.sound_timer != 0 {
            c.sound_timer -= 1
        }

        if c.delay_timer != 0 {
            c.delay_timer -= 1
        }
    }
}

computer_fetch :: proc(c: ^Computer) -> u16 {
    op_high := c.memory[c.program_counter]
    op_low := c.memory[c.program_counter + 1]

    c.program_counter += 2

    return u16(op_high) << 8 | u16(op_low)
}

computer_decode :: proc(c: ^Computer, instr: u16) -> Operation {
    first_nibble := u8(instr >> 12)
    x := u8((instr & 0x0F00) >> 8)
    y := u8((instr & 0x00F0) >> 4)
    n := u8(instr & 0x000F)
    kk := u8(instr & 0x00FF)
    nnn := instr & 0x0FFF

    switch first_nibble {
        case 0x0:
            // 00E0 - CLS
            if instr == 0x00E0 {
                return Operation_Clear{}
            }

            // 00EE - RET
            if instr == 0x00EE {
                return Operation_Return{}
            }
        case 0x1:
            // 1nnn - JP addr
            return Operation_Jump{location = nnn}
        case 0x2:
            // 2nnn - CALL addr
            return Operation_Call{addr = nnn}
        case 0x3:
            // 3xkk - SE Vx, byte
            return Operation_Skip_Equal_Immediate{register = x, value = kk}
        case 0x4:
            // 4xkk - SNE Vx, byte
            return Operation_Skip_Not_Equal_Immediate{register = x, value = kk}
        case 0x5:
            // 5xy0 - SE Vx, Vy
            return Operation_Skip_Equal{register1 = x, register2 = y}
        case 0x6:
            // 6xkk - LD Vx, byte
            return Operation_Load_Immediate{register_dest = x, value = kk}
        case 0x7:
            // 7xkk - ADD Vx, byte
            return Operation_Add_Immediate{register_dest = x, value = kk}
        case 0x8:
            switch n {
                case 0x0:
                    // 8xy0 - LD Vx, Vy
                    return Operation_Load{register_dest = x, register_source = y}
                case 0x1:
                    // 8xy1 - OR Vx, Vy
                    return Operation_Or{register_dest = x, register_op = y}
                case 0x2:
                    // 8xy2 - AND Vx, Vy
                    return Operation_And{register_dest = x, register_op = y}
                case 0x3:
                    // 8xy3 - XOR Vx, Vy
                    return Operation_Xor{register_dest = x, register_op = y}
                case 0x4:
                    // 8xy4 - ADD Vx, Vy
                    return Operation_Add{register_dest = x, register_op = y}
                case 0x5:
                    // 8xy5 - SUB Vx, Vy
                    return Operation_Sub{register_dest = x, register_op = y}
                case 0x6:
                    // 8xy6 - SHR Vx {, Vy}
                    return Operation_Shift_Right{register_dest = x, register_src = y}
                case 0x7:
                    // 8xy7 - SUBN Vx, Vy
                    return Operation_Sub_Negate{register_dest = x, register_op = y}
                case 0xE:
                    // 8xyE - SHL Vx {, Vy}
                    return Operation_Shift_Left{register_dest = x, register_src = y}
            }
        case 0x9:
            // 9xy0 - SNE Vx, Vy
            return Operation_Skip_Not_Equal{register1 = x, register2 = y}
        case 0xA:
            // Annn - LD I, addr
            return Operation_Load_Index{addr = nnn}
        case 0xB:
            // Bnnn - JP V0, addr
            return Operation_Jump_Offset{location = nnn}
        case 0xC:
            // Cxkk - RND Vx, byte
            return Operation_Load_Random{register = x, value = kk}
        case 0xD:
            // Dxyn - DRW Vx, Vy, nibble
            return Operation_Draw{register_x = x, register_y = y, bytes = n}
        case 0xE:
            switch kk {
                case 0x9E:
                    // Ex9E - SKP Vx
                    return Operation_Skip_Pressed{register_key = x}
                case 0xA1:
                    // ExA1 - SKNP Vx
                    return Operation_Skip_Not_Pressed{register_key = x}
            }
        case 0xF:
            switch kk {
                case 0x07:
                    // Fx07 - LD Vx, DT
                    return Operation_Load_Delay{register_dest = x}
                case 0x0A:
                    // Fx0A - LD Vx, K
                    return Operation_Load_Key{register_dest = x}
                case 0x15:
                    // Fx15 - LD DT, Vx
                    return Operation_Set_Delay{register_source = x}
                case 0x18:
                    // Fx18 - LD ST, Vx
                    return Operation_Set_Sound{register_source = x}
                case 0x1E:
                    // Fx1E - ADD I, Vx
                    return Operation_Index_Add{register_op = x}
                case 0x29:
                    // Fx29 - LD F, Vx
                    return Operation_Index_Sprite{register_sprite = x}
                case 0x33:
                    // Fx33 - LD B, Vx
                    return Operation_Convert_Decimal{register_op = x}
                case 0x55:
                    // Fx55 - LD [I], Vx
                    return Operation_Store_Registers{register_to = x}
                case 0x65:
                    // Fx65 - LD Vx, [I]
                    return Operation_Load_Registers{register_to = x}
            }
    }

    return Operation_Nop{}
}

computer_execute :: proc(c: ^Computer, operation: Operation) {
    switch op in operation {
        case Operation_Nop:
        case Operation_Clear:
            for i in 0..<len(c.display) {
                c.display[i] = 0
            }
        case Operation_Return:
            c.program_counter = c.stack[c.stack_pointer]
            c.stack_pointer -= 1
        case Operation_Jump:
            c.program_counter = op.location
        case Operation_Jump_Offset:
            offset := c.registers[0]

            c.program_counter = op.location + u16(offset)
        case Operation_Call:
            c.stack_pointer += 1
            c.stack[c.stack_pointer] = c.program_counter
            c.program_counter = op.addr
        case Operation_Skip_Equal_Immediate:
            x := c.registers[op.register]

            if x == op.value {
                c.program_counter += 2
            }
        case Operation_Skip_Not_Equal_Immediate:
            x := c.registers[op.register]

            if x != op.value {
                c.program_counter += 2
            }
        case Operation_Skip_Equal:
            x := c.registers[op.register1]
            y := c.registers[op.register2]

            if x == y {
                c.program_counter += 2
            }
        case Operation_Skip_Not_Equal:
            x := c.registers[op.register1]
            y := c.registers[op.register2]

            if x != y {
                c.program_counter += 2
            }
        case Operation_Skip_Pressed:
            key := c.registers[op.register_key]
            if c.keys[key] == 1 {
                c.program_counter += 2
            }
        case Operation_Skip_Not_Pressed:
            key := c.registers[op.register_key]
            if c.keys[key] == 0 {
                c.program_counter += 2
            } 
        case Operation_Load_Immediate:
            c.registers[op.register_dest] = op.value
        case Operation_Load:
            value := c.registers[op.register_source]
            c.registers[op.register_dest] = value
        case Operation_Load_Delay:
            c.registers[op.register_dest] = c.delay_timer
        case Operation_Load_Key:
            is_key_pressed := false
            for key in 0x0..=0xF {
                if c.keys[key] == 1 {
                    is_key_pressed = true
                    c.registers[op.register_dest] = u8(key)
                    break                  
                }
            }

            if !is_key_pressed {
                c.program_counter -= 2
            }
        case Operation_Load_Random:
            random := u8(rand.int_max(256))
            c.registers[op.register] = random & op.value
        case Operation_Add_Immediate:
            c.registers[op.register_dest] += op.value
        case Operation_Load_Index:
            c.index_register = op.addr
        case Operation_Or:
            x := c.registers[op.register_dest]
            y := c.registers[op.register_op]

            c.registers[op.register_dest] = x | y
        case Operation_And:
            x := c.registers[op.register_dest]
            y := c.registers[op.register_op]

            c.registers[op.register_dest] = x & y
        case Operation_Xor:
            x := c.registers[op.register_dest]
            y := c.registers[op.register_op]

            c.registers[op.register_dest] = x ~ y
        case Operation_Add:
            x := c.registers[op.register_dest]
            y := c.registers[op.register_op]

            result: u16 = u16(x) + u16(y)
            c.registers[op.register_dest] = u8(result)
            c.registers[0xF] = result > 255 ? 1 : 0
        case Operation_Sub:
            x := c.registers[op.register_dest]
            y := c.registers[op.register_op]

            c.registers[op.register_dest] = x - y
            c.registers[0xF] = x >= y ? 1 : 0
        case Operation_Sub_Negate:
            x := c.registers[op.register_dest]
            y := c.registers[op.register_op]

            c.registers[op.register_dest] = y - x
            c.registers[0xF] = y >= x ? 1 : 0
        case Operation_Shift_Left:
            y := c.registers[op.register_src]
    
            c.registers[op.register_dest] = y << 1
            c.registers[0xF] = y >> 7 == 1 ? 1 : 0
        case Operation_Shift_Right:
            y := c.registers[op.register_src]

            c.registers[op.register_dest] = y >> 1
            c.registers[0xF] = y & 1 == 1 ? 1 : 0
        case Operation_Set_Delay:
            x := c.registers[op.register_source]
            c.delay_timer = x
        case Operation_Set_Sound:
            x := c.registers[op.register_source]
            c.sound_timer = x
        case Operation_Index_Add:
            x := c.registers[op.register_op]
            c.index_register += u16(x)
        case Operation_Index_Sprite:
            char := c.registers[op.register_sprite]
            c.index_register = FONT_ADDRESS + u16(char) * FONT_CHARACTER_SIZE
        case Operation_Draw:
            start_x := c.registers[op.register_x] % 64
            start_y := c.registers[op.register_y] % 32

            c.registers[0xF] = 0

            for row in 0..<op.bytes {
                y := start_y + row
                if y >= DISPLAY_HEIGHT {
                    break
                }

                sprite_row : u8 = c.memory[c.index_register + u16(row)]
                
                for col in 0..<8 {
                    x := start_x + u8(col)
                    if x >= DISPLAY_WIDTH {
                        break
                    }

                    display_idx : u16 = u16(y) * DISPLAY_WIDTH + u16(x)

                    pixel := sprite_row >> (7 - u8(col)) & 1
                    if pixel == 1 {
                        if c.display[display_idx] == 1 {
                            c.display[display_idx] = 0
                            c.registers[0xF] = 1
                        } else {
                            c.display[display_idx] = 1
                        }
                    }
                }
            }
        case Operation_Convert_Decimal:
            x := c.registers[op.register_op]

            units := x % 10

            x /= 10
            decimals := x % 10

            x /= 10
            hundreds := x % 10

            c.memory[c.index_register] = hundreds
            c.memory[c.index_register+1] = decimals
            c.memory[c.index_register+2] = units
        case Operation_Store_Registers:
            for r in 0..=op.register_to {
                c.memory[c.index_register+u16(r)] = c.registers[r]
            }
        case Operation_Load_Registers:
            for r in 0..=op.register_to {
                c.registers[r] = c.memory[c.index_register+u16(r)]
            }
        }
}
