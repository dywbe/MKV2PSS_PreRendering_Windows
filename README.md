# PSBBN PSS Pre-Encoder for Windows

A Windows batch tool for **pre-encoding MKV movies and episodes into PlayStation 2 `.PSS` files** before importing them into **CosmicScale's PSBBN Definitive Project**.

The goal is to perform the time-consuming video/audio conversion in advance on a Windows PC.

Once a `.PSS` file has been generated, it can be placed in the PSBBN Definitive Project's `media/movie` folder, or in your configured `movie` media folder, and then processed by the PSBBN Movie Installer.

The conversion workflow and several PSBBN-oriented encoding parameters used by this project are based on the excellent work done in **CosmicScale's PSBBN Definitive Project**.

---

## What's new

The conversion pipeline has been substantially revised and stabilized.

### Improved audio/video synchronization

Earlier versions could produce PSS files where the audio became desynchronized from the video on some MKV sources.

The conversion pipeline has now been redesigned so that video and audio are generated from the **same FFmpeg input timeline**.

The script now uses timestamp-aware audio processing:

```text
aresample=48000:async=1000:first_pts=0:min_hard_comp=0.100
```

This allows FFmpeg to compensate for timing discontinuities or gaps that may exist in the original MKV audio timestamps.

The video timeline is normalized to:

```text
30000/1001
```

or approximately:

```text
29.970 fps
```

using:

```text
fps=30000/1001:start_time=0:round=near
```

After the MPEG-2 video has been encoded, the script counts the **actual number of frames** in the final `.m2v` file.

The exact target duration is calculated as:

```text
video duration = frame count × 1001 / 30000
```

The PCM WAV is then aligned to that exact video duration before PS2STR encoding.

The final audio duration is verified against the encoded MPEG-2 timeline before the WAV is converted to ADS.

The current duration verification tolerance is:

```text
± 0.002 seconds
```

This verification checks that the final PCM timeline matches the final encoded MPEG-2 duration extremely closely before PS2STR performs the final conversion and multiplexing.

This new synchronization method has been successfully tested on material that previously showed noticeable dialogue synchronization problems.

---

### Improved PS2STR installation

The Sony PS2STR tools are **not included directly in this repository**.

If they are not already available in `000_tools`, the batch automatically attempts to download the PS2STR package at runtime.

The primary package is:

```text
ps2str_v1.08_2001.zip
```

The primary Archive.org location is the same package referenced by CosmicScale's PSBBN Media Installer:

```text
https://archive.org/download/ps2str_v1.08_2001/ps2str_v1.08_2001.zip
```

Because Archive.org may occasionally return temporary HTTP errors such as `500`, `502`, connection resets, or metadata errors, the downloader can try several retrieval methods before giving up.

These include:

1. Archive.org metadata lookup.
2. Direct Archive.org storage servers when available.
3. The standard Archive.org `/download/` endpoint.
4. The Archive.org `/serve/` endpoint.
5. A secondary fallback source.

Downloaded packages are validated before extraction.

---

### PS2STR extraction has been simplified

The original PS2STR archive contains the following structure:

```text
ps2str\
└── win32\
    ├── ps2str.exe
    ├── ps2strw.exe
    └── encvag.dll
```

The batch now uses this known directory structure directly instead of trying to locate the files through recursive searches.

The archive is temporarily downloaded into:

```text
_pss_tmp\
```

and extracted into:

```text
_pss_tmp\ps2str_extract\
```

The required files are then copied to:

```text
000_tools\
```

After successful installation, the downloaded archive and extraction directory are removed.

---

## What it does

For every `.mkv` file placed next to the batch file, the script:

1. Checks that `ffmpeg.exe` and `ffprobe.exe` are available.
2. Checks for the required PS2STR runtime files.
3. Automatically downloads and extracts PS2STR when necessary.
4. Detects the MKV duration using `ffprobe`.
5. Selects a PSBBN-oriented MPEG-2 bitrate according to the duration.
6. Detects whether the source video is progressive or interlaced.
7. Generates MPEG-2 video and PCM audio from the same FFmpeg timeline.
8. Converts the video to **640×480 MPEG-2 at 30000/1001 fps**.
9. Converts the selected audio track to **48 kHz, 16-bit stereo PCM**.
10. Compensates for audio timestamp discontinuities when necessary.
11. Counts the actual MPEG-2 video frames.
12. Calculates the exact final video duration.
13. Aligns the PCM audio to the encoded MPEG-2 timeline.
14. Verifies the final audio/video duration agreement.
15. Uses `ps2str` to convert the WAV audio to Sony ADS.
16. Uses `ps2str` to multiplex the MPEG-2 video and ADS audio into a `.PSS`.
17. Writes the finished file to `000_PSS`.
18. Checks the estimated output size and lowers the MPEG-2 bitrate when necessary.

---

## Conversion pipeline

```text
                    MKV
                     │
                     │
               same timeline
                     │
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼
      MPEG-2 video          PCM audio
       640×480              48 kHz stereo
      29.970 fps                │
          │                     │
          │              timestamp correction
          │                     │
          ▼                     ▼
     frame counting       audio alignment
          │                     │
          └──────────┬──────────┘
                     │
              duration check
                     │
                     ▼
                WAV → ADS
                  PS2STR
                     │
                     ▼
             MPEG-2 + ADS
                  PS2STR
                     │
                     ▼
                    PSS
```

---

## Automatic MPEG-2 bitrate selection

The current bitrate selection is based on the duration of the source:

| Duration | MPEG-2 bitrate |
|---|---:|
| ≤ 31 min | 1800 kb/s |
| ≤ 89 min | 1600 kb/s |
| ≤ 92 min | 1400 kb/s |
| ≤ 102 min | 1200 kb/s |
| ≤ 107 min | 1000 kb/s |
| ≤ 120 min | 800 kb/s |
| > 120 min | 600 kb/s |

If the estimated output is too large for the intended PSS size constraints, the script can automatically reduce the video bitrate and encode the video again.

---

## Folder layout

### Before the first run

```text
PSBBN-PSS-PreEncoder\
│
├── 000_MKV_TO_PSS_PSBBN_RUN.bat
├── movie01.mkv
├── movie02.mkv
├── ...
│
├── 000_tools\
│   ├── ffmpeg.exe
│   └── ffprobe.exe
│
└── 000_PSS\
```

### After PS2STR has been installed automatically

```text
PSBBN-PSS-PreEncoder\
│
├── 000_MKV_TO_PSS_PSBBN_RUN.bat
├── movie01.mkv
├── movie02.mkv
├── ...
│
├── 000_tools\
│   ├── ffmpeg.exe
│   ├── ffprobe.exe
│   ├── ps2str.exe
│   ├── ps2strw.exe
│   └── encvag.dll
│
├── 000_PSS\
│
└── _pss_tmp\
```

`ps2strw.exe` is not required by the conversion batch itself, but it is part of the Win32 PS2STR package and is copied alongside the other PS2STR tools when available.

---

## Requirements

### Required manually

The following programs must be placed in:

```text
000_tools\
```

before running the batch:

```text
ffmpeg.exe
ffprobe.exe
```

### Obtained automatically when missing

The batch can obtain:

```text
ps2str.exe
ps2strw.exe
encvag.dll
```

at runtime.

---

## Usage

Place the MKV files to convert in the same directory as:

```text
000_MKV_TO_PSS_PSBBN_RUN.bat
```

For example:

```text
PSBBN-PSS-PreEncoder\
├── 000_MKV_TO_PSS_PSBBN_RUN.bat
├── Episode 01.mkv
├── Episode 02.mkv
├── Episode 03.mkv
│
├── 000_tools\
│   ├── ffmpeg.exe
│   └── ffprobe.exe
│
└── 000_PSS\
```

Then run:

```text
000_MKV_TO_PSS_PSBBN_RUN.bat
```

The first launch may automatically download and install the PS2STR tools.

Finished files are written to:

```text
000_PSS\
```

For example:

```text
000_PSS\
├── Episode 01.pss
├── Episode 02.pss
└── Episode 03.pss
```

---

## Using the generated PSS files with PSBBN

After conversion, copy the generated `.pss` files into the PSBBN Definitive Project's:

```text
media/movie\
```

or into the `movie` subfolder of your custom media location.

The PSBBN Movie Installer can then process the already-prepared PSS files without having to perform the original MKV-to-PSS transcode again.

This can save a considerable amount of processing time when preparing many movies or episodes.

---

## Existing files

By default:

```text
OVERWRITE=0
```

If a matching `.PSS` already exists in `000_PSS`, the conversion is skipped.

This is useful when processing a large collection because previously completed files do not need to be encoded again.

---

## Audio track selection

The default audio track is:

```text
AUDIO_TRACK=0
```

which means the first audio stream in the MKV.

This value can be changed near the beginning of the batch file if another audio stream should be used.

---

## Temporary files

Temporary conversion files are stored in:

```text
_pss_tmp\
```

They may include:

```text
.wav
.m2v
.ads
.mux
.pss
```

as well as temporary `ffprobe` information used during conversion.

Temporary PS2STR download/extraction files are also stored there during installation and are removed after a successful PS2STR setup.

---

## VLC playback note

VLC may be able to display the MPEG-2 video contained in a PlayStation 2 PSS file while failing to play its Sony ADS/ADPCM audio correctly.

Therefore:

```text
PSS plays video in VLC but has no sound
```

does **not necessarily mean that the PSS contains no audio**.

The final playback target remains PSBBN / PlayStation 2.

For synchronization testing, playback on the actual PS2 environment is strongly recommended.

---

# Credits and acknowledgements

## CosmicScale / PSBBN Definitive Project

The PSBBN-oriented conversion workflow and several encoding choices used by this project are based on the **Media Installer / Movie Installer** from the **PSBBN Definitive Project**, created by **CosmicScale**.

PSBBN Definitive Project:

https://github.com/CosmicScale/PSBBN-Definitive-Project

The automatic PS2STR acquisition approach was also inspired by CosmicScale's Media Installer, which retrieves the legacy PS2STR package when required.

The upstream PSBBN Definitive Project is distributed under the **GNU General Public License v3.0**.

Many thanks to CosmicScale for the PSBBN Definitive Project and for making PSBBN installation and media preparation significantly easier for the community.

---

## FFmpeg / ffprobe

`ffmpeg.exe` and `ffprobe.exe` are part of the **FFmpeg project**.

FFmpeg:

https://ffmpeg.org/

FFmpeg source:

https://github.com/FFmpeg/FFmpeg

If using Windows builds from **Gyan Doshi / gyan.dev**:

https://www.gyan.dev/ffmpeg/builds/

FFmpeg is free and open-source software, but redistribution requirements depend on the configuration and license of the exact build being distributed.

If FFmpeg binaries are redistributed with this project, the applicable FFmpeg/GPL/LGPL requirements must be respected.

FFmpeg also documents that binaries built using incompatible non-free components with `--enable-nonfree` are not redistributable.

---

## Sony Computer Entertainment legacy PS2 tools

The following files are legacy PlayStation 2 development tools associated with **Sony Computer Entertainment Inc.**:

```text
ps2str.exe
ps2strw.exe
encvag.dll
```

These files are **not authored by this project**.

They are also **not intended to be committed directly to this repository**.

When the files are missing, the batch attempts to obtain the required PS2STR package at runtime.

The primary package currently used is:

```text
ps2str_v1.08_2001.zip
```

from:

```text
https://archive.org/download/ps2str_v1.08_2001/ps2str_v1.08_2001.zip
```

This is the same Archive.org package referenced by CosmicScale's PSBBN Media Installer.

The package is downloaded and extracted locally on the end user's computer.

---

# Third-Party Notices

## PSBBN Definitive Project / CosmicScale

This project adapts parts of the movie conversion workflow and PSBBN-oriented encoding approach used by the PSBBN Definitive Project Media Installer.

Copyright:

```text
Copyright (c) 2024-2026 CosmicScale
```

Upstream project:

https://github.com/CosmicScale/PSBBN-Definitive-Project

Upstream license:

```text
GPL-3.0
```

---

## FFmpeg / ffprobe

FFmpeg and ffprobe are developed by the FFmpeg project and its contributors.

Project:

https://ffmpeg.org/

Source:

https://github.com/FFmpeg/FFmpeg

Optional Windows builds:

https://www.gyan.dev/ffmpeg/builds/

If FFmpeg binaries are included in a release, users and distributors should consult the licensing information supplied with the exact FFmpeg build.

---

## Sony Computer Entertainment legacy tools

The following third-party legacy PlayStation 2 development files may be downloaded by the batch when required:

```text
ps2str.exe
ps2strw.exe
encvag.dll
```

These files are not authored by this repository.

They are downloaded and extracted locally at runtime rather than being stored directly in the repository.

The primary PS2STR package currently referenced by this project is:

```text
https://archive.org/download/ps2str_v1.08_2001/ps2str_v1.08_2001.zip
```

These tools originate from legacy Sony Computer Entertainment PlayStation 2 development tooling.

No ownership of these files is claimed by this project.

---

# Licensing note

This repository contains an independent helper script built around FFmpeg, PS2STR and the PSBBN media preparation workflow.

Because parts of the implementation and workflow were developed with reference to the GPL-3.0-licensed PSBBN Definitive Project, contributors should review the upstream GPL-3.0 requirements when redistributing modified or derived code.

If code from the PSBBN Definitive Project has been incorporated into this project, the applicable GPL-3.0 obligations must be respected.

Third-party programs retain their own copyrights and licenses.

The presence of an automatic download mechanism does not transfer ownership or licensing rights for third-party software to this repository.

---

# Disclaimer

This project is an independent community helper tool.

It is **not affiliated with, sponsored by, approved by, or endorsed by**:

- Sony Interactive Entertainment
- Sony Computer Entertainment
- CosmicScale
- the PSBBN Definitive Project
- the FFmpeg project
- Internet Archive
- any third-party download mirror

PlayStation, PlayStation 2 and related names and trademarks belong to their respective owners.

This project exists simply to make preparing movies and videos for PlayStation 2 / PSBBN easier and faster.

Special thanks to the developers, reverse engineers, preservation communities and enthusiasts who continue to keep PlayStation 2 software and hardware useful more than two decades after its original release.
