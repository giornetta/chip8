package chip8

import "core:fmt"
import "core:reflect"

Operation :: union {
    Operation_Nop,
    Operation_Clear,
    Operation_Return,
    Operation_Jump,
    Operation_Jump_Offset,
    Operation_Call,
    Operation_Skip_Equal_Immediate,
    Operation_Skip_Not_Equal_Immediate,
    Operation_Skip_Equal,
    Operation_Skip_Not_Equal,
    Operation_Skip_Pressed,
    Operation_Skip_Not_Pressed,
    Operation_Load_Immediate,
    Operation_Load_Index,
    Operation_Load,
    Operation_Add_Immediate,
    Operation_Load_Random,
    Operation_Load_Delay,
    Operation_Load_Key,
    Operation_Set_Delay,
    Operation_Set_Sound,
    Operation_Add,
    Operation_Sub,
    Operation_Sub_Negate,
    Operation_Or,
    Operation_And,
    Operation_Xor,
    Operation_Shift_Right,
    Operation_Shift_Left,
    Operation_Draw,
    Operation_Index_Add,
    Operation_Index_Sprite,
    Operation_Convert_Decimal,
    Operation_Store_Registers,
    Operation_Load_Registers
}

Operation_Nop :: struct{}

Operation_Clear :: struct{}

Operation_Return :: struct {}

Operation_Jump :: struct {
    location: u16
}

Operation_Jump_Offset :: struct {
    location: u16
}

Operation_Call :: struct {
    addr: u16
}

Operation_Skip_Equal_Immediate :: struct {
    register: u8,
    value: u8,
}

Operation_Skip_Not_Equal_Immediate :: struct {
    register: u8,
    value: u8,
}

Operation_Skip_Equal :: struct {
    register1: u8,
    register2: u8,
}

Operation_Skip_Not_Equal :: struct {
    register1: u8,
    register2: u8,
}

Operation_Skip_Pressed :: struct{
    register_key: u8,
}

Operation_Skip_Not_Pressed :: struct{
    register_key: u8,
}

Operation_Load_Immediate :: struct {
    register_dest: u8,
    value: u8,
}

Operation_Load_Index :: struct {
    addr: u16,
}

Operation_Load :: struct {
    register_source: u8,
    register_dest: u8,
}

Operation_Load_Delay :: struct {
    register_dest: u8,
}

Operation_Load_Key :: struct {
    register_dest: u8,
}

Operation_Or :: struct {
    register_dest: u8,
    register_op: u8,
}

Operation_And :: struct {
    register_dest: u8,
    register_op: u8,
}

Operation_Xor :: struct {
    register_dest: u8,
    register_op: u8,
}

Operation_Add_Immediate :: struct {
    register_dest: u8,
    value: u8,
}

Operation_Add :: struct {
    register_dest: u8,
    register_op: u8,
}

Operation_Index_Add :: struct {
    register_op: u8,
}

Operation_Sub :: struct {
    register_dest: u8,
    register_op: u8,
}

Operation_Sub_Negate :: struct {
    register_dest: u8,
    register_op: u8,
}

Operation_Shift_Right :: struct {
    register_dest: u8,
    register_src: u8
}

Operation_Shift_Left :: struct {
    register_dest: u8,
    register_src: u8
}

Operation_Load_Random :: struct {
    register: u8,
    value: u8,
}

Operation_Draw :: struct {
    register_x: u8,
    register_y: u8,
    bytes: u8,
}

Operation_Set_Delay :: struct {
    register_source: u8,
}

Operation_Set_Sound :: struct {
    register_source: u8,
}

Operation_Index_Sprite :: struct {
    register_sprite: u8,
}

Operation_Convert_Decimal :: struct {
    register_op: u8,
}

Operation_Store_Registers :: struct {
    register_to: u8,
}

Operation_Load_Registers :: struct {
    register_to: u8,
}