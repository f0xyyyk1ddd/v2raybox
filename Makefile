APP_NAME=v2raybox
APP_BUNDLE=$(APP_NAME).app
APP_EXECUTABLE=$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)

SWIFT_FILES=$(wildcard Sources/*.swift)
SWIFT_COMPILER=swiftc
SWIFT_FLAGS=-target x86_64-apple-macosx10.13 -sdk $(shell xcrun --show-sdk-path --sdk macosx)

all: $(APP_BUNDLE)

$(APP_BUNDLE): $(APP_EXECUTABLE) Info.plist
	@echo "Copying Info.plist..."
	@mkdir -p $(APP_BUNDLE)/Contents
	@cp Info.plist $(APP_BUNDLE)/Contents/
	@echo "Build successful!"

$(APP_EXECUTABLE): $(SWIFT_FILES)
	@echo "Compiling Swift files..."
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@$(SWIFT_COMPILER) $(SWIFT_FLAGS) -o $(APP_EXECUTABLE) $(SWIFT_FILES)

clean:
	@rm -rf $(APP_BUNDLE)
