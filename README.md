# PSBBN PSS Pre-Encoder for Windows

A Windows batch tool for **pre-encoding MKV movies and episodes into PlayStation 2 `.PSS` files** before importing them into **CosmicScale's PSBBN Definitive Project**.

The goal is to perform the slow video/audio conversion in advance on a Windows PC. Once a `.PSS` file has been generated, it can be placed in the PSBBN Definitive Project's `media/movie` folder (or your configured `movie` media folder) and then processed by the PSBBN Movie Installer.

This tool is **CPU-only**. It intentionally does not use CUDA, NVDEC or NVENC, in order to stay close to the conversion workflow used by CosmicScale's PSBBN Movie Installer.

## What it does

For every `.mkv` file placed next to the batch file, the script:

1. Detects the movie duration with `ffprobe`.
2. Selects a PSBBN-style MPEG-2 bitrate according to the duration.
3. Extracts the selected audio track as 48 kHz, 16-bit stereo PCM WAV.
4. Converts the video to PSBBN-oriented MPEG-2 at 640x480 / 29.97 fps.
5. Uses `ps2str` to encode the audio to ADS.
6. Multiplexes the MPEG-2 video and ADS audio into a `.PSS` file.
7. Saves the final file in `000_PSS`.
8. Keeps/reuses complete temporary WAV/M2V files when recovery mode is enabled.

## Folder layout

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
└── 000_PSS\
```

`ps2strw.exe` is not required by the batch itself; it is only listed because it is commonly distributed alongside the legacy PS2STR tools.

## Usage

Place all MKV files to convert in the same directory as the batch file, then run:

```text
000_MKV_TO_PSS_PSBBN_RUN.bat
```

Finished files are written to:

```text
000_PSS\
```

After conversion, copy the `.pss` files into the PSBBN Definitive Project's `media/movie` folder, or into the `movie` subfolder of the custom media location configured in PSBBN.

## Credits and acknowledgements

### CosmicScale / PSBBN Definitive Project

The conversion workflow and PSBBN-oriented encoding parameters used by this batch are based on the **Media Installer / Movie Installer** from the **PSBBN Definitive Project**, created by **CosmicScale**.

PSBBN Definitive Project:
https://github.com/CosmicScale/PSBBN-Definitive-Project

The PSBBN Definitive Project is licensed under **GPL-3.0**.

### FFmpeg / ffprobe

`ffmpeg.exe` and `ffprobe.exe` are part of the **FFmpeg project**.

FFmpeg:
https://ffmpeg.org/

FFmpeg source:
https://github.com/FFmpeg/FFmpeg

If using the Windows builds from **Gyan Doshi / gyan.dev**, credit should also be given to the build distributor:

https://www.gyan.dev/ffmpeg/builds/

Gyan's current Windows FFmpeg builds are distributed as **GPLv3** builds.

### PS2STR / ENCVAG

`ps2str.exe`, `ps2strw.exe` and `encvag.dll` are legacy PlayStation 2 development tools associated with **Sony Computer Entertainment Inc.**

`encvag.dll` contains Sony Computer Entertainment Inc. copyright metadata.

### FFmpeg and ffprobe

FFmpeg is free/open-source software, but redistribution must comply with the license of the exact binary build being distributed.

The current Gyan Windows builds are static **GPLv3** builds. If you redistribute those binaries, you must comply with the GPL requirements, including providing the applicable license notices and corresponding source availability.

FFmpeg also explicitly states that a build created with `--enable-nonfree` is **not redistributable**.

### ps2str.exe, ps2strw.exe and encvag.dll

Because they are associated with Sony Computer Entertainment's PlayStation 2 development tooling, **I am not sure I can redistribute them here...**.

Instead, this repository should ideally provide only the batch script and instructions telling users to supply their own legally obtained copies of:

```text
ps2str.exe
ps2strw.exe
encvag.dll
```

And put them in the "000_tools" folder.

The fact that another project uses, downloads or references a binary does not itself grant redistribution rights.

This section is provided as a practical licensing warning. I might be wrong. Let me know directly if needed so we can agree to removal of some of these tools.

## Suggested repository license

Because this utility was created by adapting the PSBBN conversion workflow and parameters from CosmicScale's GPL-3.0 project, **GPL-3.0 is the recommended license for this repository**. But I do not license anything on this project. Feel free to do whatever you want. I just want to help people gain time to format their favorites movies or videos for their PlayStation 2.

## Disclaimer

This project is an independent helper tool and is **not affiliated with or endorsed by Sony Interactive Entertainment, Sony Computer Entertainment, CosmicScale, or the FFmpeg project**.

PlayStation, PlayStation 2 and related trademarks belong to their respective owners. Thanks them for their awesome work as always I am a Sony fan.


# Third-Party Notices

## PSBBN Definitive Project / CosmicScale

This project adapts the movie conversion workflow and PSBBN-oriented encoding parameters used by the PSBBN Definitive Project Media Installer.

Copyright (c) 2024-2026 CosmicScale.

Upstream project:
https://github.com/CosmicScale/PSBBN-Definitive-Project

Upstream license: GPL-3.0.

## FFmpeg / ffprobe

FFmpeg and ffprobe are developed by the FFmpeg project and its contributors.

Project:
https://ffmpeg.org/

Source:
https://github.com/FFmpeg/FFmpeg

When using Gyan Doshi's Windows builds:
https://www.gyan.dev/ffmpeg/builds/

The current Gyan Windows builds are GPLv3 builds. Redistribution must comply with the applicable GPL terms and source-code requirements.

## Sony Computer Entertainment legacy tools

The following files are third-party legacy PlayStation 2 development tools:

- ps2str.exe
- ps2strw.exe
- encvag.dll

These files are not authored or distributed by this repository.

When they are missing, the batch downloads the same Archive.org package referenced by CosmicScale's PSBBN Media Installer:

https://archive.org/download/ps2str_v1.08_2001/ps2str_v1.08_2001.zip

The files are downloaded and extracted locally on the end user's computer at runtime.

These SDK files are from Sony Computer Entertainment Inc.