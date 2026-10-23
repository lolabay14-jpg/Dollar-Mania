# Dollar Mania

Virtual-credit arcade. The client is a Godot 4.7 project. The API lives in `backend/`.

## Export the web build

Run this from the repo root in PowerShell. It uses the `Web` preset in `export_presets.cfg` and writes the release export to `build/web/`. That folder is gitignored.

`build/.gdignore` keeps Godot from importing the export back into the project. The command moves that file aside for the export, then restores it. If the file is missing, the rename is skipped.

The console binary is the local editor at `.tools/godot/` (also gitignored), Godot 4.7.2 with the Web export templates installed.

```powershell
Rename-Item "build\.gdignore" "build\.gdignore.bak" -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path "build\web" | Out-Null
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-release "Web" "build/web/index.html"
Rename-Item "build\.gdignore.bak" "build\.gdignore" -ErrorAction SilentlyContinue
```

Open `build/web/index.html` through a local static server. Opening the file directly will not load the WebAssembly build.
