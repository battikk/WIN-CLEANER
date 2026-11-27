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

The window follows your Windows light or dark theme.

### Weekly automatic cleanup

Tick **Weekly automatic cleanup** and pick a day and time. That is all: Windows Task Scheduler then runs the cleanup in the background with the same choices, without opening WinCleaner. If the PC is off at that time, it runs at the next start. You can move or delete the downloaded folder afterwards; the weekly run uses its own copy in `%LOCALAPPDATA%\WinCleaner`.

Prefer the console? Use `app\WinCleaner-Console.bat`: it shows a table and asks `Y/N` before cleaning.

The language follows your Windows display language (Turkish or English).

### Command line options

| Option | What it does |
|---|---|
| `-Scan` | Scan only, delete nothing |
| `-Yes` | Clean without asking |
| `-Advanced` | Also run advanced areas (Windows component store cleanup, slow) |
| `-Language tr` / `-Language en` | Force a language |
| `-InstallSchedule` | Add the weekly cleanup (default Sunday 12:00, change it in the window) |
| `-RemoveSchedule` | Remove the weekly cleanup |

Example: `.\app\WinCleaner.ps1 -Scan -Language en`

### Settings

Settings and the log are kept in `%LOCALAPPDATA%\WinCleaner`, not in the download folder. The window saves your choices there automatically. To edit by hand, `settings.json` accepts `Language`, `DisabledAreas` (area ids from `app/WinCleaner.Core.psm1`), `ScheduleDay` and `ScheduleTime`.

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
- Every cleanup is logged to `%LOCALAPPDATA%\WinCleaner\WinCleaner.log`.

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
