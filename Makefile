.PHONY: build run release icons screenshots clean

build:
	.github/scripts/build.sh

run: build
	open "build/Mac Remote Control.app"

release:
	.github/scripts/release.sh

icons:
	swift .github/scripts/make-icons.swift .

screenshots:
	node .github/scripts/screenshots.mjs

clean:
	rm -rf build dist mac/.build web/.next web/out
