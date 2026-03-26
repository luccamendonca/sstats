# sstats

Minimal macOS menu bar app showing CPU %, memory %, and network speed.

```
C:12%  M:45%  ↓12.3  ↑1.2
```

## Build

```sh
swift build -c release
```

Binary at `.build/release/sstats`.

## Run

```sh
.build/release/sstats
```

Runs as a background agent — no Dock icon, no window. Kill with `pkill sstats` or Activity Monitor.

## Config

`~/.config/sstats/config.json` (created on first run):

```json
{
  "update_interval": 2.0
}
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `update_interval` | float | `2.0` | Seconds between refreshes |

## Auto-start

Add the binary to **System Settings → General → Login Items**.
