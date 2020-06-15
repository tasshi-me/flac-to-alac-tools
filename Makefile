GOCMD=go
BINARY_NAME=flac2alac
BINARY_MAC=$(BINARY_NAME)_darwin_amd64
BINARY_LINUX=$(BINARY_NAME)_linux_amd64
BINARY_WINDOWS=$(BINARY_NAME)_windows_amd64.exe
ARTIFACTS=artifacts

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
	rm -rf $(ARTIFACTS)
run:
	$(GOCMD) .
mod:
	$(GOCMD) mod tidy
build-mac: main.go
	CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 $(GOCMD) build -o $(BINARY_MAC) -v
build-linux: main.go
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GOCMD) build -o $(BINARY_LINUX) -v
build-windows: main.go
	CGO_ENABLED=0 GOOS=windows GOARCH=amd64 $(GOCMD) build -o $(BINARY_WINDOWS) -v
$(BINARY_MAC): main.go
	make build-mac
$(BINARY_LINUX): main.go
	make build-linux
$(BINARY_WINDOWS): main.go
	make build-windows
artifacts: $(BINARY_MAC) $(BINARY_LINUX) $(BINARY_WINDOWS)
	mkdir -p $(ARTIFACTS)
	zip --junk-paths $(ARTIFACTS)/$(BINARY_MAC) $(BINARY_MAC)
	zip --junk-paths $(ARTIFACTS)/$(BINARY_LINUX) $(BINARY_LINUX)
	zip --junk-paths $(ARTIFACTS)/$(BINARY_WINDOWS) $(BINARY_WINDOWS)

