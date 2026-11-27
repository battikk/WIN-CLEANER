# WinCleaner

**Open-source, transparent cleaner for Windows 10 and 11.** It safely removes temporary files and caches that only waste disk space.

[Türkçe](README.tr.md)

- **No .exe.** Plain PowerShell you can read line by line before running it.
- **No internet access, no telemetry.** The script never connects anywhere. CI fails if a network command is ever added.
- **Scan first, delete only after you confirm.** You see how much each area uses before anything is removed.

> Status: early version. The interface is Turkish for now; English, a windowed UI and more cleaning areas are on the way (see [Roadmap](#roadmap)).

## Usage

1. Download the latest zip from [Releases](../../releases) and extract it.
2. Double-click `WinCleaner.bat` and accept the administrator prompt.
3. Review the table of areas and sizes.
4. Type `E` to clean, or `H` to exit without deleting anything.

Scan only, from PowerShell: `.\WinCleaner.ps1 -Tara`
Clean without asking (for scheduled runs): `.\WinCleaner.ps1 -Evet`

## What gets cleaned

| Area | Notes |
|---|---|
| User and Windows Temp folders | Files changed in the last 24 hours are skipped |
| Windows Update download cache | The update service is stopped briefly and restarted |
| Delivery Optimization cache | Windows' own command first, then leftovers with the service stopped |
| Thumbnail and icon cache | Windows rebuilds it when needed |
| DirectX shader cache | Rebuilt by games when needed |
| Edge, Chrome, Firefox caches | Skipped while the browser is running |
| Crash dumps and error reports | |
| Recycle Bin | Cannot be undone |

## What is never touched

Documents, Downloads, Desktop, passwords, cookies, browser history, bookmarks, installed programs and system settings.

## Safety

- Files in use are skipped, never forced.
- Junctions and symbolic links are never followed, so nothing outside the target folders can be reached.
- Drive roots and profile folders are on a hard-coded block list.
- Every cleanup is logged to `temizlik-log.txt` next to the script.

## Verify a download

Each release lists the SHA256 hash of its zip. Check yours in PowerShell:

```powershell
Get-FileHash .\WinCleaner.zip -Algorithm SHA256
```

The hash must match the one on the release page. See [SECURITY.md](SECURITY.md) for more.

## Requirements

Windows 10 or 11 with the built-in Windows PowerShell 5.1. Nothing to install.

## Roadmap

- English and Turkish interface
- Windowed interface with checkboxes, progress bar, light and dark theme
- More areas: Brave, Opera, Vivaldi, Discord, Teams, Spotify, GPU driver installer leftovers, Windows logs
- Optional weekly automatic cleanup
- Advanced section (off by default) for heavier tasks such as component store cleanup

## License

[MIT](LICENSE)
