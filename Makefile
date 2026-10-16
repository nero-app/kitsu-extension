.PHONY: fetch generate build clean

MOON ?= $(or $(shell command -v moon 2>/dev/null),$(HOME)/.moon/bin/moon)

fetch:
	cd wit && wkg fetch . --type wit

generate:
	wit-bindgen moonbit -w bindings --project-name kitsu_extractor --ignore-stub --ignore-module-file --out-dir . wit
	sed -i 's/@types/@http/g' interface/nero/extension/types/moon.pkg interface/nero/extension/types/*.mbt
	$(MOON) fmt

build:
	$(MOON) build --target wasm --release
	wasm-tools component embed wit _build/wasm/release/build/gen/gen.wasm --encoding utf16 -o _build/embedded.wasm
	wasm-tools component new _build/embedded.wasm -o _build/component.wasm
	wasm-tools metadata add --name kitsu-moonbit --version 0.1.0 _build/component.wasm -o output.wasm
	wasm-tools validate output.wasm

clean:
	$(MOON) clean
	rm -f output.wasm
