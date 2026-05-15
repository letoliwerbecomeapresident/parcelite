.PHONY: build app clean test

build:
	swift build

app:
	./build-app.sh

clean:
	swift package clean
	rm -rf dist AppIcon.iconset

test:
	swift test
