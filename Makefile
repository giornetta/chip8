.PHONY: build clean

build:
	@mkdir -p bin
	odin build src -out:bin/chip8 -collection:deps=deps

clean:
	rm -rf bin/chip8
