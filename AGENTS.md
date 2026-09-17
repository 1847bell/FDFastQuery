# AGENTS.md

**中文版**: [AGENTS_CN.md](AGENTS_CN.md)

## What this is

FDFastQuery is a small Delphi (RAD Studio XE7, VCL) library that wraps FireDAC with a fluent,
interface-based query API. The real deliverable is two units that users drop into their own
projects; the app in this repo only demonstrates them.

- `IFD.FastQuery.pas` — the library: `IFastQuery` (chainable query), `ISqlLogger`, the
  connection registry, and the built-in file logger. Must stay free of VCL and third-party deps.
- `ProjectFastQueryBridge.pas` — thin project-specific layer over the core: `TProjectDbConnKey`
  (`cnnMain`, `cnnChild`), `RegisterProjectDbConnection`, `NewQuery`.
- `FDFastQuery.dpr` + `FastQuery.pas` / `FastQuery.dfm` — Win32 VCL demo (form `TForm2`); the only
  place EhLib / DevExpress / `TFDMemTable` may appear.
- `student_demo.db` — SQLite demo database (`students` / `courses` / `grades`), tracked by Git LFS.
- `README.md` and `README_CN.md` — English and Chinese docs, kept as mirrors of each other.

## Build and verify

There is no test suite; compiling the library units is the only available check.

Delphi is installed as XE7 at `D:\Program Files (x86)\Embarcadero\Studio\15.0` (compiler version
28.0). The Win32 compiler `dcc32.exe` is a broken shim on this machine (it cannot start
`dcc32compiler.exe`), so `msbuild FDFastQuery.dproj` and CLI Win32 builds fail — build and run the
demo from the Delphi IDE (platform Win32, config `Debug`). Output goes to `Win32\Debug` (gitignored)
and SQL logs to `Win32\Debug\logs\sql\`.

To compile-check the two library units, use the working Win64 compiler and send the `.dcu` files
outside the repo:

    "D:\Program Files (x86)\Embarcadero\Studio\15.0\bin\dcc64.exe" -Q -M \
      -N0"C:\Users\<you>\AppData\Local\Temp\dcuchk\\" \
      IFD.FastQuery.pas ProjectFastQueryBridge.pas

`-N0` needs a native Windows path ending in `\`, otherwise the compiler stops with F2039. The
compiler is Chinese-localized and prints some diagnostics with empty message text; only errors
matter. The dproj's package list (EhLib 7.0, DevExpress RS21, FastReport, madExcept, Raize,
HyControl) comes from IDE-installed packages — leave it alone.

Verify behavior changes by running the demo buttons as before: Grid1 = parameterized grid query,
Grid2 = `TFDMemTable` file round-trip, Memo = row iteration. Note Grid2 writes scratch `tmp` /
`tmp.fds` files next to the exe.

## Architecture rules

- The library may only use `System.*`, `Data.DB`, `FireDAC.*` and `Winapi.Windows`. It is
  Windows-only by design (`GetTickCount`, `InterlockedIncrement`) and must not acquire a VCL,
  EhLib or other third-party dependency — that would defeat its purpose as a drop-in unit.
- The library never owns connections: `RegisterDbConnection` stores the `TFDConnection` reference
  and `UnregisterDbConnection` / `ClearDbConnections` free only the registry entry, never the
  connection. `TFDQuery` instances *are* owned by `TFastQuery` (created with a `nil` owner, freed
  in the destructor), so callers must keep the `IFastQuery` reference alive while its `DataSet` is
  bound to a grid or `TDataSource`.
- Global state is unit-level in `IFD.FastQuery.pas` (`GConnectionItems`, `GSqlLogger`,
  `GTraceSeed`), created in `initialization` and released in `finalization`. Connections are keyed
  by `IntToStr(AConnKey)` and the bridge passes `Ord(TProjectDbConnKey)`, so only **append** to that
  enum: reordering silently rebinds connections and renames them in log output. The log name is
  decided once at registration (`NormalizeConnName`; a blank name falls back to the key text) and
  read back through `ConnectionDisplayName`, and `TFastQuery.BindConnection` takes the name and the
  connection from one `TDbConnResolver.ResolveItem` lookup — keep it that way instead of looking the
  key up twice.
- All logging goes through the `TryLog*` wrappers. Logging is best-effort: swallow logger
  exceptions, never mask the original database exception, never abort a query because a log write
  failed. Keep the `[START]` / `[END]` / `[ERROR]` line format stable (documented in the READMEs).
- `Open` keeps lazy fetching (`RecordCountMode = cmFetched`), so `RecordCount` and the logged
  `ROWS` of an OPEN mean rows fetched so far, not the full result set. Don't add anything that
  forces a complete fetch.

## Conventions

- Delphi naming: `T` / `I` for types, `F` fields, `L` locals, `A` parameters, `G` unit globals.
  Chainable methods return `IFastQuery` (via `AsInterface`); `Exec: Integer` returns rows affected.
- New library units take the `IFD.` prefix; comments and identifiers are English.
- Public API or log-format changes must update **both** `README.md` and `README_CN.md`.
- `FastQuery.dfm` hardcodes `Database=D:\JQSoft\Code\FDFastQuery\student_demo.db`; moving or
  renaming the repo breaks the demo until that path is edited in the IDE.
- The README chained-query example filters on `students.class_id`, but the demo schema has
  `class_name` — the example is wrong; fix it rather than copying it.

## Repo hygiene

`*.exe`, `*.res` and `*.db` are Git LFS tracked, so `git lfs` must be installed for a fresh clone to
contain a usable `student_demo.db`. `Win32\Debug`, `__history`, `*.identcache`, `*.local`, `*.res`
and `*.skincfg` are gitignored generated artifacts; `__history` holds stale IDE backups, never edit
those copies. Tracked files are deliberately few: the `.dpr`/`.dproj`, the three `.pas` units, the
demo `.dfm`, the docs, the license and the demo database.
