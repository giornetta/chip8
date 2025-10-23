.PHONY: build clean

build:
	@mkdir -p bin
	odin build src -out:bin/chip8

clean:
	rm -rf bin/chip8
