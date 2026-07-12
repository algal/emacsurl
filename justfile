project := "EmacsURL.xcodeproj"
scheme := "EmacsURL"
derived_data := "build/DerivedData"

# Build an optimized app bundle.
build-release:
    xcodebuild -project "{{project}}" -scheme "{{scheme}}" -configuration Release -derivedDataPath "{{derived_data}}" build

# Build a debug app bundle.
build-debug:
    xcodebuild -project "{{project}}" -scheme "{{scheme}}" -configuration Debug -derivedDataPath "{{derived_data}}" build

# Remove artifacts created by the build recipes.
clean:
    rm -rf "{{derived_data}}"
