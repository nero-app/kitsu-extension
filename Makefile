.PHONY: generate build clean

generate:
	wit-bindgen moonbit -w bindings --features extension-keyvalue-ttl,extension-portal --project-name kitsu_extractor --out-dir . wit
	find gen interface world -name moon.pkg.json -delete
	rm -f moon.mod.json
	$(HOME)/.moon/bin/moon fmt

build:
	$(HOME)/.moon/bin/moon build --target wasm --release
	wasm-tools component embed wit _build/wasm/release/build/gen/gen.wasm --encoding utf16 -o _build/embedded.wasm
	wasm-tools component new _build/embedded.wasm -o _build/component.wasm
	wasm-tools metadata add --name kitsu-moonbit --version 0.1.0 _build/component.wasm -o output.wasm
	wasm-tools validate output.wasm

clean:
	$(HOME)/.moon/bin/moon clean
	rm -f output.wasm
