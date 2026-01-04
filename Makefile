.PHONY: all test clean

all: midimacro

midimacro: MidiMacro.swift
	swiftc MidiMacro.swift -o midimacro

test:
	echo "LOL"

clean:
	rm -f midimacro
