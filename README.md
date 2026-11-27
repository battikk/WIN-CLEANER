# WinCleaner

**Open-source, transparent cleaner for Windows 10 and 11.** It safely removes temporary files and caches that only waste disk space.

[Türkçe](README.tr.md)

- **No .exe.** Plain PowerShell you can read line by line before running it.
- **No internet access, no telemetry.** The script never connects anywhere. CI fails if a network command is ever added.
- **Scan first, delete only after you confirm.** You see how much each area uses before anything is removed.

## Usage

1. Download the latest zip from [Releases](../../releases) and extract it.
2. Double-click `WinCleaner.bat` and accept the administrator prompt. The WinCleaner window opens.
3. Press **Scan**. Nothing is deleted while scanning.
4. Untick any area you want to keep, then press **Clean** and confirm.

The window follows your Windows light or dark theme. Tick **Weekly automatic cleanup** to run it every Sunday with the same choices.

Prefer the console? Use `WinCleaner-Console.bat`: it shows a table and asks `Y/N` before cleaning.

The language follows your Windows display language (Turkish or English).

### Command line options

| Option | What it does |
|---|---|
| `-Scan` | Scan only, delete nothing |
| `-Yes` | Clean without asking |
| `-Advanced` | Also run advanced areas (Windows component store cleanup, slow) |
| `-Language tr` / `-Language en` | Force a language |
| `-InstallSchedule` | Add a weekly cleanup, Sundays 12:00 (runs at next start if the PC was off) |
| `-RemoveSchedule` | Remove the weekly cleanup |

Example: `.\WinCleaner.ps1 -Scan -Language en`

### Settings

Copy `settings.example.json` to `settings.json` to turn areas off or set defaults. Area ids are listed in `src/WinCleaner.Core.psm1`.

## What gets cleaned

| Area | Notes |
|---|---|
| User and Windows Temp folders | Files changed in the last 24 hours are skipped |
| Windows Update download cache | The update service is stopped briefly and restarted |
| Delivery Optimization cache | Windows' own command first, then leftovers with the service stopped |
| Thumbnail and icon cache | Windows rebuilds it when needed |
| DirectX shader cache | Rebuilt by games when needed |
| GPU shader cache (NVIDIA, AMD) | Rebuilt by the driver when needed |
| GPU driver installer leftovers | Contents of `C:\NVIDIA`, `C:\AMD` and the NVIDIA downloader folder |
| Edge, Chrome, Brave, Vivaldi, Opera, Firefox caches | Skipped while the browser is running |
| Discord and Microsoft Teams caches | Skipped while the app is running |
| Crash dumps and error reports | |
| Old Windows log files | Logs from the last 7 days are kept |
| Recycle Bin | Cannot be undone |
| *Advanced:* Windows component store | Runs `DISM /StartComponentCleanup`, only with `-Advanced` |

## What is never touched

Documents, Downloads, Desktop, passwords, cookies, browser history, bookmarks, installed programs and system settings.

## Safety

- Files in use are skipped, never forced.
- Junctions and symbolic links are never followed, so nothing outside the target folders can be reached.
- Drive roots and profile folders are on a hard-coded block list.
- Every cleanup is logged to `WinCleaner.log` next to the script.

## Verify a download

Each release lists the SHA256 hash of its zip. Check yours in PowerShell:

```powershell
Get-FileHash .\WinCleaner.zip -Algorithm SHA256
```

The hash must match the one on the release page. See [SECURITY.md](SECURITY.md) for more.

## Requirements

Windows 10 or 11 with the built-in Windows PowerShell 5.1. Nothing to install.

## Roadmap

- [x] English and Turkish interface
- [x] More areas: Brave, Opera, Vivaldi, Discord, Teams, GPU caches and installer leftovers, Windows logs
- [x] Optional weekly automatic cleanup
- [x] Advanced section (off by default)
- [x] Windowed interface with checkboxes, progress bar, light and dark theme

## License

[MIT](LICENSE)
