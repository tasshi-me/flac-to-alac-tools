GOCMD=go
BINARY_OUTPUT_DIR=dist
BINARY_NAME=flac2alac
BINARY_LOCAL=$(BINARY_OUTPUT_DIR)/$(BINARY_NAME)
BINARY_MACOS=$(BINARY_OUTPUT_DIR)/$(BINARY_NAME)_macos_amd64
BINARY_LINUX=$(BINARY_OUTPUT_DIR)/$(BINARY_NAME)_linux_amd64
BINARY_WINDOWS=$(BINARY_OUTPUT_DIR)/$(BINARY_NAME)_win_amd64

all: build-macos build-linux build-windows

build: build-macos

test:
	$(GOCMD) test -v ./...
clean:
	$(GOCMD) clean
	rm -rf $(BINARY_OUTPUT_DIR)

run:
	$(GOCMD) .
mod:
	$(GOCMD) mod tidy
build-macos: main.go
	CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 $(GOCMD) build -o $(BINARY_MACOS) -v
build-linux: main.go
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GOCMD) build -o $(BINARY_LINUX) -v
build-windows: main.go
	CGO_ENABLED=0 GOOS=windows GOARCH=amd64 $(GOCMD) build -o $(BINARY_WINDOWS).exe -v
$(BINARY_MACOS): main.go
	make build-macos
$(BINARY_LINUX): main.go
	make build-linux
$(BINARY_WINDOWS): main.go
	make build-windows
