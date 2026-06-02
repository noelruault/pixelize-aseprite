# Build the installable Aseprite extension and, optionally, the binary it
# drives. The extension is just a zip of package.json + the Lua script
# (plus the bin/ directory if you bundle a binary) renamed to
# .aseprite-extension, which Aseprite installs on double-click.

NAME    := pixelize
PKG     := $(NAME).aseprite-extension
ENGINE  := ../pixelize        # sibling checkout of noelruault/pixelize
EXE     := pixelize
ifeq ($(OS),Windows_NT)
EXE := pixelize.exe
endif

.PHONY: package bin clean

# package zips the extension. Run `make bin` first if you want the binary
# bundled inside it; otherwise the extension expects `pixelize` on PATH.
package: clean
	zip -r $(PKG) package.json pixelize.lua README.md LICENSE \
		$(if $(wildcard bin/*),bin,) -x '*.DS_Store'
	@echo "Built $(PKG)"

# bin builds the pixelize engine for the host OS into ./bin so it can be
# bundled. Cross-compile for other targets with GOOS/GOARCH, e.g.
#   GOOS=windows GOARCH=amd64 make bin
bin:
	mkdir -p bin
	cd $(ENGINE) && go build -o "$(CURDIR)/bin/$(EXE)" ./cmd/pixelize
	@echo "Built bin/$(EXE)"

clean:
	rm -f $(PKG)
