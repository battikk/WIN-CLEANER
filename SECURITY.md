# Security

## Design principles

- **Readable source only.** WinCleaner ships as plain PowerShell and a small `.bat` launcher. There is no compiled binary, installer or obfuscated code.
- **No network access.** The script contains no download, upload or web request commands. The CI workflow fails the build if one is added.
- **No telemetry.** Nothing about your system is collected or sent anywhere.
- **Narrow scope.** Only the cache and temporary folders listed in the README are touched. Junctions and symbolic links are never followed, and drive roots and profile folders are blocked.

## Verifying a release

Every release page lists the SHA256 hash of its zip and a VirusTotal scan link. Compare the hash with:

```powershell
Get-FileHash .\WinCleaner.zip -Algorithm SHA256
```

Only download from this repository's Releases page.

## Reporting a vulnerability

If you find a way WinCleaner could delete files it should not, or any other security problem, please use **Security > Report a vulnerability** on this repository (private advisory) instead of opening a public issue.
