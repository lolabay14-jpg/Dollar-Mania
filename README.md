# Dollar Mania

Virtual-credit arcade. The Godot 4.7 client stays in this repo. The API lives in `backend/`. A Next.js dashboard and game floor lives in `web/` and calls that same API.

## Next.js dashboard

From `web/`, with the API already running on port 3000:

```powershell
npm run dev
```

Open http://localhost:3001. See `web/README.md` for the player, admin, and game pages.

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
