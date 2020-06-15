GOCMD=go
BINARY_NAME=flac2alac
BINARY_MAC=$(BINARY_NAME)_darwin_amd64
BINARY_LINUX=$(BINARY_NAME)_linux_amd64
BINARY_WINDOWS=$(BINARY_NAME)_windows_amd64.exe

all: build-mac build-linux build-windows

build: build-mac

test:
	$(GOCMD) test -v ./...
clean:
	$(GOCMD) clean
	rm -f $(BINARY_NAME)
	rm -f $(BINARY_MAC)
	rm -f $(BINARY_LINUX)
	rm -f $(BINARY_WINDOWS)
run:
	$(GOCMD) .
mod:
	$(GOCMD) mod tidy
build-mac:
	CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 $(GOCMD) build -o $(BINARY_MAC) -v
build-linux:
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GOCMD) build -o $(BINARY_LINUX) -v
build-windows:
	CGO_ENABLED=0 GOOS=windows GOARCH=amd64 $(GOCMD) build -o $(BINARY_WINDOWS) -v

