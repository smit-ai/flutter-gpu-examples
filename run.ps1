# Enable detailed output and stop on error
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Define script and engine directories
$SCRIPT_DIR = (Get-Location).Path
$ENGINE_DIR = "$HOME\projects\flutter\engine\src"
$IMPELLERC = "$ENGINE_DIR\out\host_debug_unopt_arm64\impellerc"

# Create the assets directory if it doesn't exist
New-Item -ItemType Directory -Force -Path "$SCRIPT_DIR\assets" | Out-Null

# Run the impellerc command
& $IMPELLERC `
    --include="$ENGINE_DIR\flutter\impeller\compiler\shader_lib" `
    --runtime-stage-metal `
    --sl="assets\TestLibrary.shaderbundle" `
    --shader-bundle=@{
        "UnlitFragment" = @{ "type" = "fragment"; "file" = "$SCRIPT_DIR\shaders\flutter_gpu_unlit.frag" };
        "UnlitVertex" = @{ "type" = "vertex"; "file" = "$SCRIPT_DIR\shaders\flutter_gpu_unlit.vert" };
        "TextureFragment" = @{ "type" = "fragment"; "file" = "$SCRIPT_DIR\shaders\flutter_gpu_texture.frag" };
        "TextureVertex" = @{ "type" = "vertex"; "file" = "$SCRIPT_DIR\shaders\flutter_gpu_texture.vert" };
        "ColorsFragment" = @{ "type" = "fragment"; "file" = "$SCRIPT_DIR\shaders\colors.frag" };
        "ColorsVertex" = @{ "type" = "vertex"; "file" = "$SCRIPT_DIR\shaders\colors.vert" };
		"SceneFragment" = @{ "type" = "fragment"; "file" = "$SCRIPT_DIR\shaders\scene.frag" };
        "SceneVertex" = @{ "type" = "vertex"; "file" = "$SCRIPT_DIR\shaders\scene.vert" };
    }

# Present options and execute based on user selection
do {
    Write-Host "Choose an option:"
    Write-Host "1. macos"
    Write-Host "2. quit"
    $choice = Read-Host "Enter your choice (1 or 2)"

    switch ($choice) {
        "1" {
            flutter run `
                --debug `
                --local-engine-src-path $ENGINE_DIR `
                --local-engine=host_debug_unopt_arm64 `
                --local-engine-host=host_debug_unopt_arm64 `
                -d macos `
                --enable-impeller
        }
        "2" {
            break
        }
        default {
            Write-Host "Invalid option $choice"
        }
    }
} while ($true)
