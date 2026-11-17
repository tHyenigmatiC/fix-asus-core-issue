# core3-fix

Workaround for a **faulty CPU core** on an ASUS TUF Gaming A15 (FA506NCR, Ryzen 7 7435HS, 8 cores / 16 threads).
It keeps **core 3** out of both Ubuntu and Windows so the laptop stops crashing.

> This is a workaround, not a repair. The CPU is soldered to the motherboard; the real fix is a motherboard replacement.

## Set up from scratch

```bash
git clone git@github.com:tHyenigmatiC/fix-asus-core-issue.git
cd fix-asus-core-issue
sudo ./install.sh              # installs needed packages + the core3-fix command
sudo core3-fix ubuntu on       # Ubuntu skips core 3
sudo core3-fix windows 7       # Windows skips core 3 (then turn Secure Boot off in the BIOS)
```

`install.sh` fetches everything it needs from Ubuntu's repositories (`python3`, `python3-hivex`, `mokutil`,
`grub-efi-amd64-bin`). It changes no settings by itself; the `ubuntu` / `windows` commands do that.

## Quick reference

```bash
core3-fix status               # what is active now (add sudo to see Windows too)
core3-fix check                # crashes + corrupted-data errors, last 7 days
sudo core3-fix ubuntu on       # Ubuntu: 7 cores / 14 threads, core 3 skipped
sudo core3-fix windows 7       # Windows: 7 cores via GRUB entry (Secure Boot OFF)
sudo core3-fix windows 6       # Windows: 6 threads (cores 0-2), Secure Boot can stay ON
sudo core3-fix restore         # undo everything, put original files back
core3-fix help                 # full list
core3-fix help bitlocker       # BitLocker asked for the recovery key
```

## What was wrong (Nov 2026)

- Windows would not boot, even from a USB installer: a different blue screen every time
  (`PAGE_FAULT_IN_NONPAGED_AREA` in storport.sys, `IRQL_NOT_LESS_OR_EQUAL`, `SYSTEM_THREAD_EXCEPTION_NOT_HANDLED`,
  `KMODE_EXCEPTION_NOT_HANDLED`, `KERNEL_SECURITY_CHECK_FAILURE`).
- Ubuntu *looked* fine but was silently crashing too: 48 of 59 boots died ~12-15 s after starting.
- Program crashes in the Linux logs almost all ran on **CPU 6 or 7 = physical core 3**, and most had the same
  corrupted pointer `0x20000000000` (one wrong bit).
- Ruled out: SSD (SMART clean), RAM (MemTest86 passed), NVIDIA GPU (crashes continued with it untouched).
- Confirmed: with core 3 switched off, Ubuntu stopped crashing and Windows booted and stayed stable.

## How the fix works

| | How core 3 is kept out | Cores / threads |
|---|---|---|
| **Ubuntu** | Kernel boots with `maxcpus=3` (cores 0-2 only), then the `skip-bad-core` service brings up every other thread except CPUs 6 and 7. | 7 / 14 |
| **Windows mode 7** | A GRUB entry gives Windows a copy of the firmware CPU table (ACPI MADT) with APIC IDs 6 and 7 marked disabled, then starts Windows Boot Manager. Needs Secure Boot **off** (GRUB refuses to load ACPI tables while it is on). | 7 / 14 |
| **Windows mode 6** | Windows' own `numproc=6` boot option in its BCD: it uses its first 6 threads, which are cores 0-2. | 3 / 6 |

Rules for Windows mode 7:
- Start Windows **only** from the GRUB entry **"Windows 11 (7 cores, skip core 3)"**. GRUB's plain Windows
  entry is hidden on purpose; the BIOS boot menu (F8) would start Windows on all 16 threads and it will crash.
- If that entry ever says it could not load the CPU table, Secure Boot is probably on again. It refuses to start
  Windows rather than risk core 3.

## Common situations

**BitLocker asks for the recovery key** (after changing Secure Boot, a BIOS update, sometimes a GRUB update)
Key: <https://account.microsoft.com/devices/recoverykey>. After Windows starts, in an admin Terminal:
```
manage-bde -protectors -disable C:
manage-bde -protectors -enable C:
```

**After a BIOS update** — the CPU table may change. Re-run `sudo core3-fix windows 7` (it rebuilds the table from the
new firmware) and check `core3-fix status`. A BIOS update may also turn Secure Boot back on.

**Windows crashes again in mode 7** — boot Ubuntu, run `sudo core3-fix windows 6`, and run `core3-fix check`.
If Ubuntu also shows new crashes, more of the CPU may be failing.

**Ubuntu reinstalled / new disk** — install this tool again (below) and run `sudo core3-fix ubuntu on` and
`sudo core3-fix windows 7` (or `6`).

**After the motherboard is repaired** — `sudo core3-fix ubuntu off` and `sudo core3-fix windows off`
(or `sudo core3-fix restore` to put the original files back). You can turn Secure Boot back on.

**Data written while core 3 was active may be corrupted.** Check anything important created before the fix
(git repos with `git fsck`, databases, backups/archives against checksums).

## Install / update this tool

```bash
sudo ./install.sh
```
Copies the tool to `/usr/local/lib/core3-fix` and links `core3-fix` into `/usr/local/bin`.
It does not change any settings by itself.

## Files it touches

| File | Purpose |
|---|---|
| `/etc/default/grub` | `maxcpus=3`, `GRUB_DISABLE_OS_PROBER` |
| `/etc/systemd/system/skip-bad-core.service`, `/usr/local/sbin/skip-bad-core.sh` | Ubuntu: bring up all CPUs except core 3 |
| `/etc/grub.d/42_windows_skip_core3` | the Windows 7-core GRUB entry |
| `/boot/acpi/madt-skip-core3.aml` | patched CPU table for Windows |
| Windows EFI partition `EFI/Microsoft/Boot/BCD` (UUID `1679-F4EB`) | Windows thread limit (`numproc`) |

Backups of the originals: `/var/backups/core3-fix/` (older copies from the first version: `/var/backups/windows-bcd/`).

Settings at the top of the `core3-fix` script: `BAD_CORE`, `BAD_CPUS`, `BAD_APIC_IDS`, `WIN_ESP_UUID`.
To check the CPU numbering on a new setup: `grep -E "processor|core id|apicid" /proc/cpuinfo`.

## Repository layout

| Path | What |
|---|---|
| `core3-fix` | the command |
| `lib/` | helpers: BCD editor, CPU-table patcher, Ubuntu boot service |
| `install.sh` | installs packages + the command into `/usr/local` |
| `legacy/` | the step-by-step scripts used while diagnosing (GPU test, first Ubuntu/Windows fixes); kept for reference, superseded by `core3-fix` |
