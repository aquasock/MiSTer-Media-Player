# STANDARDS_CONFORMANCE.md

> **Project:** MiSTer-Media-Player  
> **Purpose:** AI-first controlled-document reference for standards, specifications, conformance rules, protocol definitions, and externally defined media behavior.
>
> **Hard boundary:** This file is **not** an engineering-knowledge log. It must not contain project architecture, optimization rationale, debugging history, preferred implementation techniques, or chronological development notes unless those statements are themselves traceable to a controlled external document.
>
> **Authority:** The cited controlled document always outranks this file.

---

## 0. AI OPERATING RULES

```yaml
schema_version: 2

authority_order:
  - exact_application_specification
  - formal_standard_or_recommendation
  - official_corrigendum_or_amendment
  - official_industry_specification
  - official_vendor_or_platform_interface_specification
  - official_technical_report

never_primary_authority:
  - forum_post
  - wiki
  - blog
  - reverse_engineering_note
  - source_code_comment
  - AI_output

source_version_policy:
  generic_media:
    rule: >
      Prefer the current in-force edition unless the input format or application
      specification normatively pins an older edition.
  dvd_video:
    rule: >
      DVD-Video application constraints and the exact editions normatively
      referenced by the applicable DVD Format Book govern DVD-Video conformance.
      A newer generic MPEG/UDF standard must not silently replace a DVD-pinned
      edition or profile.
  udf_on_dvd_video:
    rule: >
      Do not substitute current UDF for DVD-Video UDF requirements. DVD-Video
      historically uses the UDF 1.02 profile; consult the DVD application profile
      and UDF 1.02 material specifically.
  proprietary_specs:
    rule: >
      If a normative source is licensed, confidential, or otherwise restricted,
      keep it registered here and mark access accordingly. Do not replace it with
      folklore or a third-party reverse-engineering document and call the result
      standards-conformant.

citation_rule: >
  Every normative conclusion added below this source catalog must identify the
  source_id plus an exact clause, section, table, figure, annex, page, command,
  field, or register reference.

atomicity_rule: >
  One standards record should represent one externally defined rule or one
  tightly coupled rule set.

reverification_triggers:
  - source edition changes
  - applicable application profile changes
  - source code contradicts the recorded conclusion
  - hardware test contradicts the recorded conclusion
  - wording or edge cases matter beyond the stored summary
  - record confidence is below HIGH
  - source access was previously incomplete
```

---

# 1. CONTROLLED SOURCE CATALOG

The catalog is intentionally broader than the features implemented today. `priority`
means how likely MiSTer-Media-Player is to need the document, not whether the feature
is already implemented.

Priority meanings:

```yaml
P0: "Already central to current implementation."
P1: "Expected for the next major playback milestones."
P2: "Very likely for DVD/CD completeness or planned hardware support."
P3: "Plausible future compatibility or optional feature."
```

Access meanings:

```yaml
FREE: "Controlled text is publicly obtainable."
PAID: "Controlled text is sold by the standards body."
LICENSED: "Controlled text requires an adopter/license relationship."
RESTRICTED: "Technical material exists but access is controlled/confidential."
MIXED: "Some relevant material is public; normative portions may be restricted."
```

---

## 1.1 MPEG-2 VIDEO, SYSTEMS, AND CONFORMANCE

```yaml
- source_id: H262
  priority: P0
  authority: ITU-T / ISO/IEC
  document: "ITU-T H.262 — Information technology — Generic coding of moving pictures and associated audio information: Video"
  equivalent: "ISO/IEC 13818-2:2013"
  edition: "ITU-T H.262 (02/2012), published text includes Amendment 1 (03/2013); ISO/IEC 13818-2:2013 Edition 3"
  status: "In force / Published"
  access: PAID
  official_url: "https://www.itu.int/rec/T-REC-H.262"
  iso_url: "https://www.iso.org/standard/61152.html"
  use_for:
    - elementary MPEG-2 video syntax
    - start codes
    - sequence and GOP syntax
    - picture headers and extensions
    - slices, macroblocks, blocks
    - VLC interpretation
    - quantization
    - inverse quantization
    - inverse DCT requirements
    - motion vectors and motion compensation
    - I/P/B pictures
    - frame and field pictures
    - progressive/interlaced behavior
    - chroma formats and chroma siting semantics
    - aspect ratio and frame-rate signaling
    - profile and level limits
    - VBV model
    - color-description signaling
  notes: >
    Primary normative source for the current FPGA MPEG-2 video decoder.
    DVD-Video adds a stricter application profile; H.262 alone does not define DVD menus,
    VOB structure, DVD stream restrictions, or navigation.

- source_id: H222
  priority: P0
  authority: ITU-T / ISO/IEC
  document: "ITU-T H.222.0 — Information technology — Generic coding of moving pictures and associated audio information: Systems"
  equivalent: "ISO/IEC 13818-1:2025"
  edition: "ITU-T H.222.0 (04/2025), v10; ISO/IEC 13818-1:2025 Edition 10"
  status: "In force / Published"
  access: PAID
  official_url: "https://www.itu.int/rec/T-REC-H.222.0"
  iso_url: "https://www.iso.org/standard/91403.html"
  use_for:
    - MPEG-2 Program Stream syntax
    - MPEG-2 Transport Stream syntax
    - pack headers
    - system headers
    - PES packets
    - stream_id semantics
    - SCR
    - PTS
    - DTS
    - clock and timing relationships
    - STD buffering model
    - program stream maps
    - private streams
    - multiplexing and synchronization
  notes: >
    Primary normative source for .mpg/.mpeg Program Streams and for the MPEG systems
    layer embedded inside DVD VOBs. DVD-Video constrains and extends how private
    streams and navigation data are used.

- source_id: MPEG2-CONFORMANCE
  priority: P1
  authority: ISO/IEC
  document: "ISO/IEC 13818-4:2004 — Generic coding of moving pictures and associated audio information — Part 4: Conformance testing"
  edition: "Edition 2, 2004, with applicable corrigenda/amendments"
  status: "Published; confirmed"
  access: PAID
  official_url: "https://www.iso.org/standard/40092.html"
  use_for:
    - decoder conformance methodology
    - coded-data conformance methodology
    - decoder capability claims
    - test construction
    - MPEG-2 conformance test sequences
    - cross-checking Parts 1, 2, and 3 requirements
  applicable_updates:
    - "ISO/IEC 13818-4:2004/Cor 1:2007"
    - "ISO/IEC 13818-4:2004/Cor 2:2011"
    - "ISO/IEC 13818-4:2004/Cor 3:2012"
    - "ISO/IEC 13818-4:2004/Amd 2:2005 — additional audio conformance test sequences"
  notes: >
    Use when changing from feature-by-feature testing to formal decoder conformance work.

- source_id: MPEG2-SIMULATION
  priority: P2
  authority: ISO/IEC
  document: "ISO/IEC TR 13818-5:2005 — Generic coding of moving pictures and associated audio information — Part 5: Software simulation"
  edition: "Edition 2, 2005"
  status: "Published; confirmed"
  access: PAID
  official_url: "https://www.iso.org/standard/39486.html"
  use_for:
    - reference-style software simulation
    - cross-checking decoder interpretation
    - comparison against standardized example algorithms
  notes: >
    Informative/reference aid, not a replacement for Parts 1–4.
```

---

## 1.2 MPEG AUDIO AND DVD AUDIO CODECS

```yaml
- source_id: MPEG1-AUDIO
  priority: P1
  authority: ISO/IEC
  document: "ISO/IEC 11172-3:1993 — Coding of moving pictures and associated audio for digital storage media at up to about 1,5 Mbit/s — Part 3: Audio"
  edition: "Edition 1, 1993 + Technical Corrigendum 1:1996"
  status: "Published; current/confirmed"
  access: PAID
  official_url: "https://www.iso.org/standard/22412.html"
  use_for:
    - MPEG-1 Audio Layers I, II, and III
    - MPEG audio frame syntax
    - sampling-frequency and bitrate semantics
    - Layer II decoding likely relevant to MPEG files and DVD variants
  notes: >
    MPEG-1 Layer II is a likely audio target after silent MPEG-2 video playback.

- source_id: MPEG2-AUDIO
  priority: P1
  authority: ISO/IEC
  document: "ISO/IEC 13818-3:1998 — Generic coding of moving pictures and associated audio information — Part 3: Audio"
  edition: "Edition 2, 1998"
  status: "Published; current/confirmed"
  access: PAID
  official_url: "https://www.iso.org/standard/26797.html"
  use_for:
    - MPEG-2 backwards-compatible audio extensions
    - multichannel MPEG audio
    - lower sampling-frequency extensions
  notes: >
    Consult together with ISO/IEC 11172-3 for MPEG audio compatibility.

- source_id: AC3
  priority: P1
  authority: ATSC
  document: "ATSC A/52:2018 — Digital Audio Compression (AC-3) (E-AC-3) Standard"
  edition: "Approved 25 January 2018"
  status: "ATSC 1.0 Standard"
  access: FREE
  official_url: "https://www.atsc.org/atsc-documents/a522012-digital-audio-compression-ac-3-e-ac-3-standard-12172012/"
  use_for:
    - Dolby Digital / AC-3 coded representation
    - AC-3 decoder behavior
    - channel configuration
    - metadata affecting reproduction
    - downmix-related metadata
    - E-AC-3 only if later needed outside DVD-Video
  notes: >
    AC-3 is a major DVD-Video audio format. DVD-specific stream carriage and allowed
    parameters must still be checked against the DVD-Video application specification.

- source_id: DTS
  priority: P2
  authority: ETSI
  document: "ETSI TS 102 114 — DTS Coherent Acoustics; Core and Extensions with Additional Profiles"
  edition: "ETSI repository contains releases through V1.6.1 (2019); verify exact edition before clause-level citation"
  status: "Published"
  access: FREE
  official_url: "https://www.etsi.org/deliver/etsi_TS/102100_102199/102114/"
  use_for:
    - DTS Coherent Acoustics bitstream syntax
    - DTS core decoding
    - extension profiles if ever supported
  notes: >
    Optional DVD audio feature. DVD-Video carriage constraints remain governed by
    the DVD application specification.

- source_id: MPEG2-AAC
  priority: P3
  authority: ISO/IEC
  document: "ISO/IEC 13818-7:2006 — Generic coding of moving pictures and associated audio information — Part 7: Advanced Audio Coding (AAC)"
  edition: "Edition 4, 2006 + applicable amendment/corrigendum"
  status: "Published"
  access: PAID
  official_url: "https://www.iso.org/standard/43345.html"
  use_for:
    - MPEG-2 AAC streams if broader MPEG transport/program support eventually requires them
  notes: >
    Not required for normal DVD-Video playback. Keep as a low-priority general-media source.
```

---

# 2. DVD-VIDEO APPLICATION, NAVIGATION, MENUS, AND DISC STRUCTURE

These are the most important future sources after generic MPEG playback.

```yaml
- source_id: DVD-VIDEO
  priority: P1
  authority: "DVD Format/Logo Licensing Corporation (DVD FLLC)"
  document: "DVD Specifications for Read-Only Disc, Part 3 — Video Specifications"
  edition: "VERIFY_FROM_AUTHORIZED_COPY before normative citation"
  status: "Controlled DVD Format Book"
  access: LICENSED
  official_access_note: >
    DVD FLLC produces, maintains, and issues DVD Format Books. Exact current/target
    edition must be established from an authorized copy rather than a third-party summary.
  official_context_url: "https://www.dvdcca.org/css/processb"
  use_for:
    - DVD-Video directory and file roles
    - VIDEO_TS.IFO / VIDEO_TS.BUP / VIDEO_TS.VOB
    - VTS_XX_0.IFO / VTS_XX_0.BUP / VTS_XX_N.VOB
    - VMG and VTS domains
    - title sets
    - titles and parts-of-title
    - PGC / PGCI structures
    - programs and cells
    - playback chains
    - seamless and non-seamless playback rules
    - multi-angle behavior
    - parental-management structures
    - DVD virtual-machine commands
    - pre/post/cell commands
    - button command execution
    - menu domains
    - root/title/chapter/audio/subpicture/angle menus
    - button groups and highlight state
    - NAV packs
    - PCI packets
    - DSI packets
    - VOBUs
    - cell elapsed-time/navigation data
    - DVD subpicture units
    - menu subpictures
    - subtitle stream semantics
    - audio stream attributes
    - subpicture stream attributes
    - DVD LPCM syntax/constraints
    - AC-3/MPEG/DTS carriage restrictions
    - MPEG-2 video restrictions specific to DVD-Video
    - allowed DVD resolutions/frame rates/aspect behavior
    - still pictures and still times
    - user-operation prohibitions
    - resume behavior as defined by the application model
  notes: >
    This is the authoritative source family for the "DVD player" behavior that H.262
    and H.222.0 do not define. Menu navigation, IFO semantics, NAV packets, buttons,
    chapters, cells, PGCs, subpictures, angles, and DVD VM behavior must ultimately
    trace here. Do not promote libdvdread headers, online DVD structure guides, or
    reverse-engineered notes to normative authority.

- source_id: DVD-FILESYSTEM-BOOK
  priority: P1
  authority: "DVD Format/Logo Licensing Corporation (DVD FLLC)"
  document: "DVD Specifications for Read-Only Disc, Part 2 — File System Specifications"
  edition: "VERIFY_FROM_AUTHORIZED_COPY"
  status: "Controlled DVD Format Book"
  access: LICENSED
  official_context_url: "https://www.dvdcca.org/css/processb"
  use_for:
    - DVD-specific file-system application constraints
    - exact DVD read-only file-system conformance requirements
    - application restrictions layered on UDF/ISO file structures
  notes: >
    Public ECMA/UDF documents below are preferred whenever they fully cover the needed
    rule. Use the licensed DVD book when exact DVD-specific restrictions are required.

- source_id: DVD-UDF-BRIDGE
  priority: P1
  authority: Ecma International
  document: "ECMA TR/71 — DVD read-only disk — File system specifications"
  edition: "1st edition, February 1998"
  status: "Published Technical Report"
  access: FREE
  official_url: "https://ecma-international.org/publications-and-standards/technical-reports/ecma-tr-71/"
  use_for:
    - DVD read-only UDF Bridge profile
    - relation between ECMA-167/UDF and ECMA-119
    - DVD-Video-compliant UDF Bridge domain
    - public controlled guidance on DVD read-only file-system restrictions
  notes: >
    ECMA states that the UDF Bridge is based on ECMA-167, shall conform to UDF 1.02,
    and includes a DVD-Video-compliant domain. This is a particularly valuable free
    controlled source for filesystem work.

- source_id: UDF-1.02
  priority: P1
  authority: Ecma International
  document: "ECMA TR/112 — Universal Disk Format (UDF) specification, Part 7: UDF revision 1.02"
  edition: "ECMA TR/112 1st edition, December 2023; Part 7 reproduces UDF 1.02"
  status: "Published Technical Report"
  access: FREE
  official_url: "https://ecma-international.org/publications-and-standards/technical-reports/ecma-tr-112/"
  use_for:
    - UDF 1.02 descriptors
    - volume recognition
    - partition structures
    - file entries
    - allocation descriptors
    - directory/file traversal
    - DVD filesystem parsing
  notes: >
    Use Part 7 specifically for DVD-Video-era UDF. Do not substitute UDF 2.60 simply
    because it is newer.

- source_id: ECMA-167
  priority: P1
  authority: Ecma International
  document: "ECMA-167 — Volume and file structure for write-once and rewritable media using non-sequential recording for information interchange"
  equivalent: "ISO/IEC 13346"
  edition: "3rd edition, June 1997"
  status: "Published"
  access: FREE
  official_url: "https://ecma-international.org/publications-and-standards/standards/ecma-167/"
  use_for:
    - base volume structures underlying UDF
    - volume and boot-block recognition
    - volume structure
    - file structure
    - record structure
  notes: >
    UDF is a profile/implementation of structures defined by this source family.

- source_id: DVD-PHYSICAL
  priority: P2
  authority: Ecma International
  document: "ECMA-267 — 120 mm DVD — Read-only disk"
  equivalent: "ISO/IEC 16448"
  edition: "3rd edition, April 2001"
  status: "Published"
  access: FREE
  official_url: "https://ecma-international.org/publications-and-standards/standards/ecma-267/"
  use_for:
    - physical DVD read-only disc structure
    - sector organization
    - recorded-signal format
    - logical/physical disc interchange facts
    - disc-layer and geometry questions
  notes: >
    Most low-level physical behavior should remain hidden behind the optical drive,
    but this is the controlled public reference when physical DVD facts matter.
```

---

# 3. DVD CONTENT PROTECTION, AUTHENTICATION, AND REGION CONTROL

```yaml
- source_id: CSS
  priority: P1
  authority: "DVD Copy Control Association (DVD CCA)"
  document: "Content Scramble System (CSS) specifications and CSS Procedural Specifications"
  edition: "Current licensed materials; verify exact applicable technical specification"
  status: "Maintained by DVD CCA"
  access: RESTRICTED
  official_url: "https://www.dvdcca.org/css"
  use_for:
    - CSS authentication
    - CSS key handling
    - CSS descrambling requirements
    - CSS-enabled player behavior
    - copy-control obligations
    - region-related CSS behavior where specified
  notes: >
    DVD CCA states that it licenses and maintains CSS specifications and that technical
    specifications are provided according to license category. Do not fill normative CSS
    gaps from DeCSS/libdvdcss/reverse-engineered descriptions and label them standards facts.

- source_id: CSS-PROCEDURAL
  priority: P1
  authority: "DVD Copy Control Association (DVD CCA)"
  document: "CSS Procedural Specifications"
  edition: "Current downloadable procedural specification"
  status: "Official controlled licensing/procedural document"
  access: MIXED
  official_url: "https://www.dvdcca.org/css/processb"
  use_for:
    - identifying licensing categories
    - determining which CSS technical materials govern a product class
    - procedural requirements surrounding CSS implementation
  notes: >
    Procedural specification access does not imply access to all confidential technical
    cryptographic material.
```

---

# 4. OPTICAL-DRIVE COMMANDS AND LINUX HOST INTERFACE

```yaml
- source_id: MMC6
  priority: P1
  authority: "INCITS / T10"
  document: "MultiMedia Command Set - 6 (MMC-6)"
  standard_number: "ANSI INCITS 468-2010"
  amendment: "ANSI INCITS 468-2010/AM 1"
  edition: "MMC-6 final T10 revision 02g; published standard with Amendment 1"
  status: "Published"
  access: PAID
  official_url: "https://www.t10.org/members/w_mmc6.htm"
  drafts_index: "https://www.t10.org/drafts.htm"
  use_for:
    - optical-drive command set
    - media status
    - capacity
    - READ commands applicable to optical media
    - READ CD
    - READ DVD STRUCTURE
    - GET CONFIGURATION
    - GET EVENT/STATUS NOTIFICATION
    - disc information
    - TOC/session information
    - tray/load/eject commands
    - audio-CD commands
    - DVD authentication-related packet commands
    - RPC/region-related drive behavior where defined
  notes: >
    Primary command-set specification for CD/DVD/BD-class SCSI multimedia devices.

- source_id: SPC5
  priority: P2
  authority: "INCITS / T10"
  document: "SCSI Primary Commands - 5 (SPC-5)"
  standard_number: "ANSI INCITS 502"
  edition: "Final T10 revision 22, published 2019"
  status: "Published"
  access: PAID
  official_url: "https://www.t10.org/drafts.htm"
  use_for:
    - SCSI command framework
    - inquiry
    - request sense
    - status and sense-data semantics
    - generic command processing needed alongside MMC
  notes: >
    Use with MMC-6 when issuing raw SCSI packet commands.

- source_id: LINUX-CDROM-UAPI
  priority: P1
  authority: "Linux kernel project"
  document: "Linux userspace API — Summary of CDROM ioctl calls"
  edition: "Use documentation matching or not newer than the MiSTer Linux kernel when ABI details matter"
  status: "Official kernel userspace API documentation"
  access: FREE
  official_url: "https://www.kernel.org/doc/html/latest/userspace-api/ioctl/cdrom.html"
  use_for:
    - DVD_READ_STRUCT ioctl
    - DVD_AUTH ioctl
    - CDROM_SEND_PACKET ioctl
    - CDROMREADTOCENTRY
    - CDROMREADAUDIO
    - media-change detection
    - drive/disc status
    - eject/load operations
    - Linux optical-drive UAPI behavior
  notes: >
    This is a controlled platform interface specification, not an optical-media standard.
    It defines the likely minimal Linux-side bridge to the existing kernel optical stack.

- source_id: USB20
  priority: P2
  authority: USB-IF
  document: "Universal Serial Bus Specification Revision 2.0 and incorporated ECNs/errata"
  edition: "USB-IF document package updated 3 June 2025"
  status: "Official USB base specification"
  access: FREE
  official_url: "https://www.usb.org/document-library/usb-20-specification"
  use_for:
    - USB enumeration and transfer semantics if host-level USB behavior ever matters
    - endpoint/control/bulk transfer definitions
    - USB 2.0 electrical/protocol requirements
  notes: >
    Current architecture should let Linux own USB. This source becomes important only if
    troubleshooting USB-layer behavior or implementing more of the host stack ourselves.

- source_id: USB-MSC-BOT
  priority: P2
  authority: USB-IF
  document: "USB Mass Storage Class — Bulk-Only Transport 1.0"
  edition: "30 September 1999"
  status: "Official USB device-class specification"
  access: FREE
  official_url: "https://www.usb.org/documents?category%5B0%5D=49"
  use_for:
    - CBW/CSW transport
    - bulk-only mass-storage command transport
    - USB optical drives that expose SCSI through BOT
  notes: >
    Linux should normally hide this layer from MiSTer-Media-Player.

- source_id: USB-UASP
  priority: P3
  authority: USB-IF
  document: "USB Attached SCSI Protocol (UASP) v1.0"
  edition: "24 June 2009"
  status: "Official USB device-class specification"
  access: FREE
  official_url: "https://www.usb.org/documents?category%5B0%5D=49"
  use_for:
    - SCSI command transport over USB using UAS
  notes: >
    Relevant only if a drive/bridge uses UAS and Linux no longer completely abstracts it.

- source_id: USB-UFI
  priority: P3
  authority: USB-IF
  document: "Mass Storage UFI Command Specification 1.0"
  edition: "14 December 1998"
  status: "Official USB mass-storage command specification"
  access: FREE
  official_url: "https://www.usb.org/documents?category%5B0%5D=49"
  use_for:
    - legacy USB optical/floppy-style UFI command behavior if encountered
```

---

# 5. VIDEO COLORIMETRY, SD/HD OUTPUT, AND ANALOG VIDEO REFERENCES

```yaml
- source_id: BT601
  priority: P1
  authority: ITU-R
  document: "Recommendation ITU-R BT.601-7 — Studio encoding parameters of digital television for standard 4:3 and wide screen 16:9 aspect ratios"
  edition: "BT.601-7, March 2011"
  status: "In force"
  access: FREE
  official_url: "https://www.itu.int/rec/R-REC-BT.601/en"
  use_for:
    - SD digital component-video sampling
    - SD YCbCr/R'G'B' relationships
    - 525-line and 625-line studio encoding parameters
    - color conversion questions for SD MPEG/DVD content

- source_id: BT709
  priority: P2
  authority: ITU-R
  document: "Recommendation ITU-R BT.709-6 — Parameter values for the HDTV standards for production and international programme exchange"
  edition: "BT.709-6, June 2015"
  status: "In force"
  access: FREE
  official_url: "https://www.itu.int/rec/R-REC-BT.709/en"
  use_for:
    - HDTV colorimetry
    - MPEG streams signaling BT.709 matrix/color characteristics
    - HD output color conversion

- source_id: BT470
  priority: P2
  authority: ITU-R
  document: "Recommendation ITU-R BT.470-7 — Conventional analogue television systems"
  edition: "BT.470-7, February 2005"
  status: "In force"
  access: FREE
  official_url: "https://www.itu.int/rec/R-REC-BT.470/en"
  use_for:
    - legacy analogue television system parameters
    - PAL/NTSC-family conventional television questions
  notes: >
    Use only when the actual analog-output mode depends on conventional television-system
    parameters. RGB output through MiSTer may not require all composite-video provisions.
```

---

# 6. HDMI / DIGITAL AUDIO OUTPUT — CONDITIONAL FUTURE SOURCES

These are registered because simultaneous HDMI/analog output and possible compressed-audio
passthrough have been discussed. MiSTer's common framework may already abstract much of this.

```yaml
- source_id: HDMI14B
  priority: P3
  authority: "HDMI Licensing Administrator / HDMI Founders"
  document: "HDMI Specification Version 1.4b"
  edition: "1.4b"
  status: "Official HDMI specification"
  access: LICENSED
  official_url: "https://www.hdmi.org/spec/hdmi1_4b"
  use_for:
    - HDMI source behavior if project-specific HDMI logic is ever added
    - video/audio packetization questions not already handled by MiSTer framework
  notes: >
    Do not duplicate HDMI work already correctly provided by the MiSTer framework merely
    because the specification is registered here.

- source_id: CTA861
  priority: P3
  authority: "Consumer Technology Association"
  document: "ANSI/CTA-861-I — A DTV Profile for Uncompressed High Speed Digital Interfaces"
  edition: "CTA-861-I with published errata"
  status: "Published ANSI/CTA standard"
  access: PAID
  official_url: "https://shop.cta.tech/products/cta-861"
  use_for:
    - standardized consumer video timings
    - video-format identification
    - interface signaling associated with HDMI/DVI-class consumer displays

- source_id: IEC60958
  priority: P3
  authority: IEC
  document: "IEC 60958-1:2021 — Digital audio interface — Part 1: General"
  edition: "Edition 4.0, 2021"
  status: "Published"
  access: PAID
  official_url: "https://webstore.iec.ch/en/publication/71031"
  use_for:
    - linear PCM digital audio interface semantics
    - base framing used by non-linear PCM carriage standards

- source_id: IEC61937
  priority: P3
  authority: IEC
  document: "IEC 61937 series — Digital audio — Interface for non-linear PCM encoded audio bitstreams applying IEC 60958"
  edition: "Use current applicable part; series bundle current in 2026"
  status: "Published"
  access: PAID
  official_url: "https://webstore.iec.ch/en/publication/6141"
  use_for:
    - AC-3 passthrough
    - DTS passthrough
    - MPEG audio passthrough
    - compressed audio over IEC 60958/HDMI-style paths
  notes: >
    Only needed if MiSTer-Media-Player later passes compressed audio through instead of
    decoding everything to PCM.
```

---

# 7. CD, CD-ROM, VCD/SVCD, AND MPEG-1 EXPANSION

```yaml
- source_id: CDDA
  priority: P2
  authority: IEC
  document: "IEC 60908:1999 — Audio recording — Compact disc digital audio system"
  edition: "Edition 2.0, 1999"
  status: "Published; stability date 2038"
  access: PAID
  official_url: "https://webstore.iec.ch/en/publication/3885"
  use_for:
    - CD-DA disc/player interchange
    - audio-CD track/frame behavior
    - physical/logical CD audio rules
  notes: >
    Primary controlled source if physical USB CD support includes audio-CD playback.

- source_id: CDROM-PHYSICAL
  priority: P3
  authority: Ecma International
  document: "ECMA-130 — Data interchange on read-only 120 mm optical data disks (CD-ROM)"
  edition: "June 1996"
  status: "Published"
  access: FREE
  official_url: "https://ecma-international.org/technical-committees/tc31/?tab=published-standards"
  use_for:
    - CD-ROM physical/logical disc interchange facts

- source_id: ISO9660
  priority: P2
  authority: ISO/IEC
  document: "ISO/IEC 9660:2023 — Information processing — Volume and file structure of CD-ROM for information interchange"
  equivalent_current_ecma: "ECMA-119, 6th edition, December 2025"
  edition: "ISO/IEC 9660:2023"
  status: "Published"
  access: PAID
  official_url: "https://www.iso.org/standard/81979.html"
  free_equivalent_url: "https://ecma-international.org/publications-and-standards/standards/ecma-119/"
  use_for:
    - CD-ROM directory/file structures
    - ISO 9660 filesystem images
    - UDF Bridge relationship where applicable
  notes: >
    For historical DVD UDF Bridge conformance, consult ECMA TR/71 and the edition/profile
    referenced by the DVD-era specification rather than assuming the 2023/2025 editions
    are drop-in normative replacements.

- source_id: SVCD
  priority: P3
  authority: IEC
  document: "IEC 62107:2000 — Super video compact disc — Disc-interchange system-specification"
  edition: "Edition 1.0, 2000"
  status: "Published; stability date 2039"
  access: PAID
  official_url: "https://webstore.iec.ch/en/publication/6468"
  use_for:
    - Super Video CD disc structure
    - MPEG-2-on-CD application constraints
  notes: >
    Natural future extension because the project already targets MPEG-2 and physical CD/DVD drives.

- source_id: MPEG1-SYSTEMS
  priority: P3
  authority: ISO/IEC
  document: "ISO/IEC 11172-1:1993 — Coding of moving pictures and associated audio for digital storage media at up to about 1,5 Mbit/s — Part 1: Systems"
  edition: "Edition 1, 1993"
  status: "Published; current/confirmed"
  access: PAID
  official_url: "https://www.iso.org/standard/19180.html"
  use_for:
    - MPEG-1 Systems streams
    - legacy .mpg streams
    - VCD-family systems-layer support

- source_id: MPEG1-VIDEO
  priority: P3
  authority: ISO/IEC
  document: "ISO/IEC 11172-2:1993 — Coding of moving pictures and associated audio for digital storage media at up to about 1,5 Mbit/s — Part 2: Video"
  edition: "Edition 1, 1993 + applicable corrigenda"
  status: "Published"
  access: PAID
  official_url: "https://www.iso.org/standard/22411.html"
  use_for:
    - MPEG-1 video decoding
    - legacy .mpg and VCD-family video

- source_id: MPEG1-CONFORMANCE
  priority: P3
  authority: ISO/IEC
  document: "ISO/IEC 11172-4:1995 — Part 4: Compliance testing"
  edition: "Edition 1, 1995"
  status: "Published; confirmed"
  access: PAID
  official_url: "https://www.iso.org/standard/22691.html"
  use_for:
    - MPEG-1 bitstream/decoder compliance methodology

- source_id: VCD-WHITE-BOOK
  priority: P3
  authority: "Philips / Sony and applicable format licensors"
  document: "Video CD specification ('White Book')"
  edition: "VERIFY AUTHORIZED TARGET EDITION before use"
  status: "Controlled proprietary format specification"
  access: RESTRICTED
  official_url: null
  use_for:
    - Video CD application/file structure if VCD playback is implemented
  notes: >
    Keep this placeholder rather than treating third-party VCD FAQs as normative.
    IEC 62107 covers Super Video CD, not ordinary Video CD.
```

---

# 8. TOPIC → SOURCE ROUTING MAP

This section is deliberately terse. A future AI should scan it before researching.

| Question / implementation area | First source | Then consult |
|---|---|---|
| MPEG-2 start codes, headers, slices, macroblocks | `H262` | `MPEG2-CONFORMANCE` |
| MPEG-2 I/P/B picture decoding | `H262` | `MPEG2-CONFORMANCE`, `MPEG2-SIMULATION` |
| Motion vectors / motion compensation | `H262` | `MPEG2-CONFORMANCE` |
| IDCT / inverse quantization | `H262` | `MPEG2-CONFORMANCE`, `MPEG2-SIMULATION` |
| Interlaced/field-picture behavior | `H262` | DVD profile if disc playback |
| MPEG Program Stream parsing | `H222` | DVD profile for VOB restrictions |
| PTS/DTS/SCR and A/V timing | `H222` | `DVD-VIDEO` for disc-specific behavior |
| PES/private_stream_1 in a normal `.mpg` | `H222` | codec spec indicated by payload |
| PES/private streams inside a DVD VOB | `DVD-VIDEO` | `H222`, codec spec |
| DVD VIDEO_TS / VTS file meanings | `DVD-VIDEO` | `DVD-FILESYSTEM-BOOK` |
| IFO parsing | `DVD-VIDEO` | — |
| PGC / PGCI / chapters / cells | `DVD-VIDEO` | — |
| DVD menu navigation | `DVD-VIDEO` | — |
| DVD VM commands | `DVD-VIDEO` | — |
| DVD menu buttons / highlights | `DVD-VIDEO` | — |
| DVD NAV packs / PCI / DSI | `DVD-VIDEO` | `H222` where packet syntax overlaps |
| DVD VOBU navigation | `DVD-VIDEO` | — |
| DVD subtitles/subpictures | `DVD-VIDEO` | — |
| DVD still-frame/menu-still behavior | `DVD-VIDEO` | — |
| DVD angles | `DVD-VIDEO` | — |
| DVD parental-management structures | `DVD-VIDEO` | CSS source if protection/region semantics overlap |
| DVD file-system parsing | `UDF-1.02` | `DVD-UDF-BRIDGE`, `ECMA-167` |
| DVD UDF Bridge restrictions | `DVD-UDF-BRIDGE` | `UDF-1.02`, `ECMA-119/ISO9660` |
| Raw DVD physical geometry/sector facts | `DVD-PHYSICAL` | target DVD Format Book |
| AC-3 decode | `AC3` | `DVD-VIDEO` for allowed DVD carriage |
| MPEG Layer II decode | `MPEG1-AUDIO` | `MPEG2-AUDIO`, `DVD-VIDEO` |
| DTS decode | `DTS` | `DVD-VIDEO` |
| DVD LPCM | `DVD-VIDEO` | output-interface specs only as needed |
| CSS authentication/descrambling | `CSS` | `MMC6`, `LINUX-CDROM-UAPI` |
| DVD drive authentication ioctl | `LINUX-CDROM-UAPI` | `MMC6`, `CSS` |
| Raw optical command packet | `MMC6` | `SPC5`, `LINUX-CDROM-UAPI` |
| Drive tray/media status | `MMC6` | `LINUX-CDROM-UAPI` |
| Audio-CD TOC / playback | `CDDA` | `MMC6`, `LINUX-CDROM-UAPI` |
| USB optical transport problem | `USB20` | `USB-MSC-BOT` or `USB-UASP` |
| SD YCbCr→RGB/colorimetry | `BT601` | `H262` color signaling |
| HD MPEG colorimetry | `BT709` | `H262` |
| PAL/NTSC analog-system detail | `BT470` | board/interface-specific controlled docs |
| HDMI packet/interface behavior | `HDMI14B` | `CTA861` |
| Compressed audio passthrough | `IEC61937` | `IEC60958`, codec spec |
| Legacy MPEG-1 `.mpg` | `MPEG1-SYSTEMS` | `MPEG1-VIDEO`, `MPEG1-AUDIO` |
| Super Video CD | `SVCD` | `H262`, MPEG audio specs, ISO9660 |
| Ordinary Video CD | `VCD-WHITE-BOOK` | MPEG-1 standards, ISO9660 |

---

# 9. DVD-VIDEO FEATURE CHECKLIST — SOURCE ROUTING ONLY

This is **not** a statement of DVD normative behavior. It is a list of areas that must be
resolved from the controlled DVD source before claiming complete DVD-Video support.

```yaml
dvd_video_research_queue:
  disc_recognition_and_domains:
    source: DVD-VIDEO
    topics:
      - First Play PGC
      - Video Manager domain
      - Video Title Set domain
      - title/menu domain transitions

  information_files:
    source: DVD-VIDEO
    topics:
      - VMGI
      - VTSI
      - IFO/BUP relationship
      - title search pointer tables
      - part-of-title tables
      - time maps
      - stream attributes

  playback_graph:
    source: DVD-VIDEO
    topics:
      - PGC
      - program
      - cell
      - cell playback information
      - cell position information
      - seamless flags
      - still time
      - playback time

  navigation_packets:
    source: DVD-VIDEO
    topics:
      - NAV pack placement
      - PCI
      - DSI
      - VOBU search/navigation fields
      - seamless-angle navigation
      - menu highlight information

  virtual_machine:
    source: DVD-VIDEO
    topics:
      - GPRM
      - SPRM
      - command encoding
      - branching
      - link/jump/call behavior
      - pre-commands
      - post-commands
      - cell commands
      - button commands
      - resume-related state

  menus_and_buttons:
    source: DVD-VIDEO
    topics:
      - menu types
      - button groups
      - selected/activated button states
      - directional navigation
      - highlight color/contrast
      - button command execution

  subpictures:
    source: DVD-VIDEO
    topics:
      - subpicture packetization
      - SPU command sequences
      - palette interpretation
      - display areas
      - timing
      - subtitle selection
      - menu overlays

  angles_and_seamless_playback:
    source: DVD-VIDEO
    topics:
      - angle blocks
      - interleaved units
      - seamless angle changes
      - cell ordering constraints

  audio:
    source: DVD-VIDEO
    topics:
      - stream numbering
      - language/application attributes
      - AC-3 carriage
      - MPEG audio carriage
      - LPCM carriage
      - DTS carriage
      - channel and sampling constraints

  video:
    source: DVD-VIDEO
    topics:
      - permitted MPEG-2 profiles/levels
      - permitted dimensions
      - frame-rate restrictions
      - aspect ratio
      - display mode
      - pan_scan_and_letterbox_permissions

  parental_and_region_related:
    source: DVD-VIDEO
    topics:
      - parental-management structures
      - country/locale-related navigation fields
    additional_sources:
      - CSS
      - MMC6

  copy_protection:
    source: CSS
    topics:
      - authentication
      - descrambling
      - key exchange
      - drive/player roles
      - region/RPC interactions where applicable
```

---

# 10. CONTROLLED CONFORMANCE RECORDS

This section is the fast-path lookup layer for standards-sensitive engineering.
Records here are concise, atomic conclusions already established for the project.
When a matching record exists and no reverification trigger from Section 0 applies,
use the stored conclusion directly instead of re-researching the underlying standard.
The controlled source identified by `source_id` remains authoritative.

## 10.1 FAST LOOKUP INDEX

```yaml
lookup:
  decoded_pel_reconstruction: H262-001
  prediction_plus_residual: H262-001
  clipping_0_255: H262-001
  reference_frame_definition: H262-002
  p_picture_reference_selection: H262-002
  p_prediction_samples: H262-003
  motion_compensation_reference_sampling: H262-003
  half_sample_interpolation: H262-004
  implicit_zero_p_prediction: H262-005
  chroma_420_block_order: H262-006
  macroblock_width: H262-007
  slice_macroblock_row: H262-008
  macroblock_address_progression: H262-009
  non_intra_first_coefficient_vlc: H262-010
  table_b14_first_coefficient: H262-010
  p_motion_forward_only_macroblock_type: H262-011
  table_b3_motion_forward_only: H262-011
  motion_code_zero_vlc: H262-012
  table_b10_motion_code_zero: H262-012
  macroblock_address_increment_one_vlc: H262-013
  table_b1_mba_increment_one: H262-013
  macroblock_address_increment_vlc: H262-014
  table_b1_macroblock_address_increment: H262-014
  macroblock_escape: H262-014
  skipped_macroblock_p_frame: H262-015
  p_frame_skipped_prediction: H262-015
  table_b3_motion_and_pattern: H262-018
  p_macroblock_mc_coded_vlc: H262-018
  coded_block_pattern_63_vlc: H262-019
  table_b9_cbp_63: H262-019
  coded_block_pattern_vlc_420: H262-021
  table_b9_coded_block_pattern_420: H262-021
  p_residual_block_selection_420: H262-021
  table_b14_run0_level7: H262-020
  controlled_non_intra_plus7_eob: H262-020
  motion_vector_reconstruction: H262-022
  table_b10_general_motion_code: H262-022
  p_frame_motion_predictor: H262-022
  chroma_420_motion_rounding: H262-023
  half_sample_interpolation_exact: H262-023
  non_intra_escape_coefficient: H262-024
  table_b14_escape: H262-024
```

## 10.2 ESTABLISHED ATOMIC RECORDS

```yaml
- record_id: H262-001
  title: "Decoded pel reconstruction and clipping"
  status: VERIFIED
  verified_date: 2026-08-13
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2012), published text includes Amendment 1 (03/2013)"
  source_reference: "7.6.8"
  normative_force: SEMANTICS
  controlled_conclusion: >
    A decoded pel is formed by adding the spatial-domain residual sample f[y][x]
    to the prediction sample p[y][x]. Results below 0 are clipped to 0 and results
    above 255 are clipped to 255.
  applicability: >
    Reconstruction of decoded picture samples after prediction and inverse transform.
  exceptions: []
  conformance_effect: >
    Every reconstructed 8-bit pel must equal the specified prediction-plus-residual
    sum after saturation to the inclusive range 0 through 255.
  verification_method:
    type: TEST
    description: "Compare reconstructed pels against prediction-plus-residual sums, including low/high saturation cases."
  related_records: [H262-003, H262-004, H262-005]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-13
      change: "Initial fast-path record from established project proof chain."

- record_id: H262-002
  title: "Reference frame definition and P-picture reference use"
  status: VERIFIED
  verified_date: 2026-08-13
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2012), published text includes Amendment 1 (03/2013)"
  source_reference: "3.111; 7.6.2.2"
  normative_force: DEFINITION
  controlled_conclusion: >
    A reference frame is a reconstructed I- or P-frame used for subsequent prediction.
    Frame prediction in a P-picture uses the applicable previously reconstructed
    reference frame.
  applicability: >
    Frame-picture prediction for P-pictures and reference-picture management.
  exceptions: []
  conformance_effect: >
    Prediction must use reconstructed reference-picture samples rather than coded
    coefficients, pre-reconstruction samples, or the current destination picture.
  verification_method:
    type: REVIEW
    description: "Trace P prediction input samples to the reconstructed reference frame selected by the picture-reference rules."
  related_records: [H262-003, H262-005]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-13
      change: "Initial fast-path record from established project reference-frame proof."

- record_id: H262-003
  title: "Prediction samples derive from reference samples and motion vectors"
  status: VERIFIED
  verified_date: 2026-08-13
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2012), published text includes Amendment 1 (03/2013)"
  source_reference: "7.6.4"
  normative_force: SEMANTICS
  controlled_conclusion: >
    Motion-compensated prediction samples are derived from samples in the applicable
    reference picture at locations determined by the decoded motion vector and the
    prediction rules.
  applicability: >
    Motion-compensated prediction of non-intra macroblocks in predictive pictures.
  exceptions: []
  conformance_effect: >
    The predictor presented to reconstruction must correspond to the specified
    reference-picture location for the decoded motion vector.
  verification_method:
    type: TEST
    description: "Use controlled reference-picture coordinates and motion vectors and compare returned prediction samples."
  related_records: [H262-001, H262-002, H262-004, H262-005]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-13
      change: "Initial fast-path record from established motion-compensation proof."

- record_id: H262-004
  title: "Half-sample motion-compensation interpolation"
  status: VERIFIED
  verified_date: 2026-08-13
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2012), published text includes Amendment 1 (03/2013)"
  source_reference: "7.6.4"
  normative_force: SEMANTICS
  controlled_conclusion: >
    When a motion-vector component selects a half-sample position, the prediction
    sample is formed from the neighboring integer-position reference samples using
    the interpolation and rounding arithmetic specified for motion compensation.
  applicability: >
    Prediction positions containing a half-sample horizontal and/or vertical component.
  exceptions: []
  conformance_effect: >
    Half-sample prediction values must match the standard interpolation result,
    including its prescribed rounding behavior.
  verification_method:
    type: TEST
    description: "Exercise controlled half-sample vectors against known neighboring reference pels and compare exact interpolated values."
  related_records: [H262-001, H262-003]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-13
      change: "Initial fast-path record from established half-pel arithmetic proof."

- record_id: H262-005
  title: "Implicit-zero forward prediction for controlled P macroblock case"
  status: VERIFIED
  verified_date: 2026-08-13
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2012), published text includes Amendment 1 (03/2013)"
  source_reference: "7.6.3.5"
  normative_force: SEMANTICS
  controlled_conclusion: >
    For the applicable non-intra P-picture macroblock case in which no forward
    motion vector is transmitted, prediction is formed using the standard's
    implicit prediction-vector behavior; the controlled project test case resolves
    to a zero forward vector.
  applicability: >
    The controlled pattern-only P macroblock case already used by the project,
    with macroblock_intra equal to 0 and no transmitted forward motion vector.
  exceptions: []
  conformance_effect: >
    The controlled case must predict from the colocated reference position before
    residual addition.
  verification_method:
    type: TEST
    description: "Use a controlled P macroblock with no transmitted forward vector and verify colocated reference prediction."
  related_records: [H262-001, H262-002, H262-003]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-13
      change: "Initial fast-path record from established implicit-zero P proof."

- record_id: H262-006
  title: "4:2:0 macroblock block order"
  status: VERIFIED
  verified_date: 2026-08-13
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2012), published text includes Amendment 1 (03/2013)"
  source_reference: "6.1.3; Figure 6-10"
  normative_force: SYNTAX
  controlled_conclusion: >
    For 4:2:0 macroblocks, the six block order is Y0, Y1, Y2, Y3, Cb, Cr. The four
    luma blocks cover the 16x16 luma macroblock and each chroma component contributes
    one 8x8 block for the same macroblock.
  applicability: >
    MPEG-2 Video macroblocks when chroma_format is 4:2:0.
  exceptions: []
  conformance_effect: >
    Block parsing, transform association, reconstruction, and component placement
    must preserve this six-block ordering and component identity.
  verification_method:
    type: TEST
    description: "Trace six consecutive coded blocks and verify Y0/Y1/Y2/Y3/Cb/Cr identity and placement."
  related_records: []
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-13
      change: "Initial fast-path record from established 4:2:0 reconstruction mapping."

- record_id: H262-007
  title: "Macroblock width calculation"
  status: VERIFIED
  verified_date: 2026-08-13
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2012), published text includes Amendment 1 (03/2013)"
  source_reference: "6.3.3"
  normative_force: DEFINITION
  controlled_conclusion: >
    Macroblock width is the horizontal picture size rounded upward to a whole
    number of 16-sample macroblocks: (horizontal_size + 15) / 16 using integer division.
  applicability: >
    Deriving macroblock-row width from coded horizontal picture size.
  exceptions: []
  conformance_effect: >
    Macroblock addressing and coordinate derivation must use the rounded-up macroblock width.
  verification_method:
    type: ANALYSIS
    description: "Evaluate boundary widths around multiples of 16 and compare the resulting macroblock count."
  related_records: [H262-008, H262-009]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-13
      change: "Initial fast-path record from established picture-geometry logic."

- record_id: H262-008
  title: "Slice vertical position identifies macroblock row"
  status: VERIFIED
  verified_date: 2026-08-13
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2012), published text includes Amendment 1 (03/2013)"
  source_reference: "6.3.16"
  normative_force: SEMANTICS
  controlled_conclusion: >
    slice_vertical_position identifies the macroblock row associated with the slice;
    for sufficiently large vertical sizes the slice_vertical_position_extension
    contributes the additional high-order row bits.
  applicability: >
    Slice-to-macroblock-row coordinate derivation.
  exceptions: []
  conformance_effect: >
    Reconstructed block coordinates must use the row selected by the slice vertical-position fields.
  verification_method:
    type: ANALYSIS
    description: "Decode slice position fields and compare the derived macroblock row with block placement."
  related_records: [H262-007, H262-009]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-13
      change: "Initial fast-path record from established slice-coordinate logic."

- record_id: H262-009
  title: "Macroblock address progression within a slice"
  status: VERIFIED
  verified_date: 2026-08-13
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2012), published text includes Amendment 1 (03/2013)"
  source_reference: "6.3.17"
  normative_force: SEMANTICS
  controlled_conclusion: >
    At slice start, previous_macroblock_address is initialized from the slice row
    and macroblock width, and each macroblock_address_increment advances the current
    macroblock address from that previous value.
  applicability: >
    Macroblock-address and block-coordinate progression within each slice.
  exceptions: []
  conformance_effect: >
    Macroblock placement must restart from the slice-defined address basis and advance
    according to each decoded macroblock_address_increment.
  verification_method:
    type: TEST
    description: "Exercise first and subsequent macroblocks in a slice, including increments greater than one, and compare coordinates."
  related_records: [H262-007, H262-008]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-13
      change: "Initial fast-path record from established macroblock-address logic."

- record_id: H262-010
  title: "First coefficient VLC rule for coded non-intra blocks"
  status: VERIFIED
  verified_date: 2026-08-13
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2012), published text includes Amendment 1 (03/2013)"
  source_reference: "7.2.2.2; Annex B Table B.14"
  normative_force: SYNTAX
  controlled_conclusion: >
    The first coefficient of a coded non-intra block uses the modified first-coefficient
    interpretation of Table B.14. The run=0, level=1 first-coefficient form is coded
    by the special leading code followed by its sign; end_of_block is not a legal
    first coefficient of a coded non-intra block. Subsequent coefficients use the
    ordinary Table B.14 interpretation.
  applicability: >
    Decoding the first and subsequent transform coefficients of coded non-intra blocks.
  exceptions: []
  conformance_effect: >
    The decoder must distinguish the first-coefficient rule from the subsequent-coefficient
    VLC interpretation and must reject EOB as the first coefficient of a coded non-intra block.
  verification_method:
    type: TEST
    description: "Use controlled first-coefficient and subsequent-coefficient codewords and verify run/level/sign/EOB interpretation."
  related_records: []
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-13
      change: "Initial fast-path record from established P residual syntax work."

- record_id: H262-011
  title: "P-picture motion-forward-only macroblock_type VLC"
  status: VERIFIED
  verified_date: 2026-08-13
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2012), published text includes Amendment 1 (03/2013)"
  source_reference: "Annex B Table B.3"
  normative_force: TABLE_VALUE
  controlled_conclusion: >
    For a non-scalable P-picture, macroblock_type VLC 001 selects the
    motion-forward-only macroblock type: forward motion information is present,
    while macroblock_pattern, macroblock_intra, and macroblock_quant are not set.
  applicability: >
    Decoding macroblock_type in non-scalable P-pictures.
  exceptions: []
  conformance_effect: >
    A decoder that receives Table B.3 code 001 in the applicable P-picture context
    must route the macroblock through forward prediction without coded residual
    blocks unless other syntax outside this table entry requires them.
  verification_method:
    type: TEST
    description: "Decode controlled Table B.3 code 001 and verify the resulting macroblock flags."
  related_records: [H262-003, H262-009, H262-012]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-13
      change: "Added as a fast-path table value while establishing the controlled two-P-macroblock diagnostic."

- record_id: H262-012
  title: "motion_code zero VLC"
  status: VERIFIED
  verified_date: 2026-08-13
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2012), published text includes Amendment 1 (03/2013)"
  source_reference: "Annex B Table B.10"
  normative_force: TABLE_VALUE
  controlled_conclusion: >
    In Table B.10, the one-bit VLC 1 represents motion_code equal to zero.
  applicability: >
    Decoding motion_code for MPEG-2 motion-vector components.
  exceptions: []
  conformance_effect: >
    The one-bit code 1 must decode to motion_code 0; the motion-vector component
    reconstruction rules then apply using that decoded value and the applicable predictor.
  verification_method:
    type: TEST
    description: "Decode the one-bit Table B.10 code and verify motion_code=0."
  related_records: [H262-003, H262-011]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-13
      change: "Added as a fast-path table value while establishing the controlled two-P-macroblock diagnostic."

- record_id: H262-013
  title: "macroblock_address_increment value-one VLC"
  status: VERIFIED
  verified_date: 2026-08-13
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2012), published text includes Amendment 1 (03/2013)"
  source_reference: "Annex B Table B.1"
  normative_force: TABLE_VALUE
  controlled_conclusion: >
    In Table B.1, the one-bit VLC 1 represents macroblock_address_increment equal to 1.
  applicability: >
    Decoding macroblock_address_increment within a slice.
  exceptions: []
  conformance_effect: >
    The one-bit code 1 advances the current macroblock address by exactly one from
    the previous macroblock address under the progression rule in H262-009.
  verification_method:
    type: TEST
    description: "Decode consecutive one-bit Table B.1 codes and verify adjacent macroblock addresses."
  related_records: [H262-007, H262-008, H262-009, H262-011]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-13
      change: "Added as a fast-path table value while establishing the controlled two-P-macroblock diagnostic."

- record_id: H262-014
  title: "macroblock_address_increment VLC table and escape accumulation"
  status: VERIFIED
  verified_date: 2026-08-14
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2000), official freely available consolidated edition"
  source_reference: "6.3.17; Annex B Table B.1"
  normative_force: TABLE_VALUE
  controlled_conclusion: >
    Table B.1 maps macroblock_address_increment values 1 through 33 to VLCs as follows:
    1=1, 2=011, 3=010, 4=0011, 5=0010, 6=00011, 7=00010, 8=0000111,
    9=0000110, 10=00001011, 11=00001010, 12=00001001, 13=00001000,
    14=00000111, 15=00000110, 16=0000010111, 17=0000010110,
    18=0000010101, 19=0000010100, 20=0000010011, 21=0000010010,
    22=00000100011, 23=00000100010, 24=00000100001, 25=00000100000,
    26=00000011111, 27=00000011110, 28=00000011101, 29=00000011100,
    30=00000011011, 31=00000011010, 32=00000011001, 33=00000011000.
    macroblock_escape is the fixed code 00000001000 and contributes 33 to the
    increment before the following escape(s) and terminal Table B.1 code are accumulated.
  applicability: >
    Decoding slice-local macroblock address progression in non-scalable MPEG-2 Video syntax.
  exceptions:
    - "macroblock_stuffing from ISO/IEC 11172-2 is not available in this MPEG-2 Video syntax."
  conformance_effect: >
    A decoder shall recover each coded macroblock address by adding the decoded increment,
    including 33 for every preceding macroblock_escape, to previous_macroblock_address.
  verification_method:
    type: TEST
    description: >
      Decode representative short and long Table B.1 VLCs plus an escape-prefixed value,
      then verify the recovered increment and resulting macroblock address.
  related_records: [H262-007, H262-008, H262-009, H262-013, H262-015]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-14
      change: >
        Added from the official freely available ITU-T H.262 (02/2000) text while
        generalizing the P-picture address parser beyond increment one. The project
        source catalog still identifies the later H.262 (02/2012) edition as current.

- record_id: H262-015
  title: "Skipped macroblocks in a P frame picture"
  status: VERIFIED
  verified_date: 2026-08-14
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2000), official freely available consolidated edition"
  source_reference: "6.3.17; 7.6.6; 7.6.6.2"
  normative_force: DECODE_PROCESS
  controlled_conclusion: >
    Except at slice start, a positive value of
    macroblock_address - previous_macroblock_address - 1 is the number of skipped
    macroblocks. A skipped macroblock carries no coded macroblock data; the decoder forms
    a prediction and uses it as the final decoded sample values. For a skipped macroblock
    in a P frame picture, prediction is frame-based, motion-vector predictors are reset
    to zero, and the motion vector is (0,0). The syntax does not permit the first or last
    macroblock of a slice to be skipped.
  applicability: >
    Non-scalable P frame pictures, including the project's current progressive 4:2:0
    frame-picture subset.
  exceptions:
    - "Field-picture skipped-macroblock prediction follows separate rules in 7.6.6.1."
    - "B-picture skipped-macroblock prediction follows separate rules in 7.6.6.3 and 7.6.6.4."
  conformance_effect: >
    For the current supported P frame-picture subset, each skipped address must reconstruct
    from the forward reference using a zero frame motion vector and no residual contribution.
  verification_method:
    type: TEST
    description: >
      Decode a P frame slice containing macroblock_address_increment greater than one,
      verify the inferred skipped address count, reconstruct each skipped macroblock from
      zero-vector reference prediction, and verify destination persistence.
  related_records: [H262-002, H262-003, H262-005, H262-009, H262-014]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-14
      change: >
        Added from the official freely available ITU-T H.262 (02/2000) text for the
        accelerated P-picture skipped-macroblock integration phase. The project source
        catalog still identifies the later H.262 (02/2012) edition as current.


- record_id: H262-016
  title: "Controlled f_code 3 forward motion-vector reconstruction to +32"
  status: VERIFIED
  verified_date: 2026-08-14
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2000), official freely available consolidated edition"
  source_reference: "7.6.3.1; Annex B Table B.10"
  normative_force: DECODE_PROCESS
  controlled_conclusion: >
    Table B.10 assigns the VLC 0000010110 to positive motion_code 8. For a
    frame-prediction component with f_code equal to 3, motion_residual equal to 3,
    and a zero motion-vector predictor, the 7.6.3.1 reconstruction process yields
    a reconstructed component of +32 half-sample luma units. No wrap adjustment is
    required for this controlled value.
  applicability: >
    The controlled progressive P-frame aligned-motion regression used to prove a
    full-macroblock non-zero forward prediction while retaining the established
    frame-prediction mode.
  exceptions:
    - "This record documents one controlled reconstruction case; it is not a restriction on other legal motion_code, motion_residual, f_code or predictor values."
  conformance_effect: >
    The controlled bit sequence for motion_code +8 and residual 3 at f_code 3 must
    reconstruct to +32 before reference-sample addressing.
  verification_method:
    type: TEST
    description: >
      Decode the controlled Table B.10 code and two residual bits, reconstruct the
      component from zero PMV, and verify the result is exactly +32.
  related_records: [H262-003, H262-004, H262-012]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-14
      change: >
        Added from the official freely available ITU-T H.262 (02/2000) text while
        integrating the first full-raster non-zero forward-motion prediction proof.

- record_id: H262-017
  title: "4:2:0 chroma motion-vector scaling"
  status: VERIFIED
  verified_date: 2026-08-14
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2000), official freely available consolidated edition"
  source_reference: "7.6.3.7"
  normative_force: DECODE_PROCESS
  controlled_conclusion: >
    For 4:2:0 chroma prediction, the horizontal and vertical chroma motion-vector
    components are derived by dividing the corresponding reconstructed luma
    motion-vector components by two according to the H.262 chroma-vector process.
    Thus the controlled luma vector (+32,0) half-sample units corresponds to a
    chroma vector (+16,0) half-sample units, which is an eight-chroma-sample
    horizontal displacement.
  applicability: >
    4:2:0 motion-compensated prediction in the project's current progressive
    frame-picture P subset.
  exceptions:
    - "Other chroma formats use their respective H.262 chroma motion-vector derivation rules."
  conformance_effect: >
    Chroma reference addressing for the controlled aligned-motion macroblock must
    select the chroma block one macroblock column to the right when luma uses the
    +32 horizontal vector.
  verification_method:
    type: TEST
    description: >
      Use distinct Cb and Cr macroblock tiles, apply the controlled (+32,0) luma
      vector, and verify the reconstructed chroma samples come from the adjacent
      8x8 chroma blocks selected by the scaled vector.
  related_records: [H262-003, H262-006, H262-016]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-14
      change: >
        Added from the official freely available ITU-T H.262 (02/2000) text for
        the accelerated aligned full-4:2:0 motion-compensation integration proof.

- record_id: H262-018
  title: "P-picture macroblock_type MC+Coded VLC"
  status: VERIFIED
  verified_date: 2026-08-14
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2000), official freely available consolidated edition"
  source_reference: "Annex B Table B.3"
  normative_force: TABLE_VALUE
  controlled_conclusion: >
    In a non-scalable P picture, macroblock_type VLC 1 selects
    macroblock_motion_forward=1 and macroblock_pattern=1 with macroblock_quant=0
    and macroblock_intra=0.  This is the motion-compensated, coded-residual
    macroblock type used by the controlled mixed P regression.
  applicability: >
    Non-scalable P pictures, including the project's current progressive 4:2:0 frame-picture subset.
  exceptions: []
  conformance_effect: >
    After decoding VLC 1, the decoder must decode forward motion-vector syntax and
    coded_block_pattern/residual syntax for the same non-intra macroblock.
  verification_method:
    type: TEST
    description: "Decode a controlled P macroblock with VLC 1 and verify both motion prediction and coded residual reconstruction are applied."
  related_records: [H262-003, H262-011, H262-016, H262-019]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-14
      change: "Added for the first mixed motion+residual P-raster integration boundary."

- record_id: H262-019
  title: "coded_block_pattern value 63 VLC"
  status: VERIFIED
  verified_date: 2026-08-14
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2000), official freely available consolidated edition"
  source_reference: "Annex B Table B.9"
  normative_force: TABLE_VALUE
  controlled_conclusion: >
    Table B.9 assigns coded_block_pattern value 63 the VLC 001100.  For 4:2:0,
    value 63 marks all six macroblock blocks Y0,Y1,Y2,Y3,Cb,Cr as coded.
  applicability: "Non-intra 4:2:0 macroblocks carrying coded_block_pattern."
  exceptions: []
  conformance_effect: >
    The controlled mixed macroblock using 001100 must process residual block syntax
    for all six 4:2:0 blocks in the established block order.
  verification_method:
    type: TEST
    description: "Decode 001100 as CBP=63 and verify six residual blocks are processed."
  related_records: [H262-006, H262-018]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-14
      change: "Added alongside H262-018 for the controlled MC+Coded regression."

- record_id: H262-020
  title: "Controlled non-intra run 0 level +7 coefficient and EOB"
  status: VERIFIED
  verified_date: 2026-08-14
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2000), official freely available consolidated edition"
  source_reference: "7.2.2.2; Annex B Table B.14"
  normative_force: TABLE_VALUE
  controlled_conclusion: >
    For a coded non-intra block whose first coefficient is not the special
    run=0, level=1 form, the ordinary Table B.14 VLC is used with the first
    leading zero retained.  The Table B.14 VLC 0000001010 represents run=0,
    level=7; sign bit 0 makes the level positive.  A following ordinary Table
    B.14 code 10 is end_of_block.
  applicability: "The controlled six-block MC+Coded residual used by Phase 1U-o."
  exceptions: []
  conformance_effect: >
    Each controlled block bit sequence 0000001010 0 10 must decode to one
    run=0, level=+7 coefficient followed by EOB.
  verification_method:
    type: TEST
    description: "Decode the controlled first coefficient and EOB, then verify the shared non-intra IQ/IDCT path."
  related_records: [H262-010, H262-018, H262-019]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-14
      change: "Added for the controlled mixed motion+residual raster vector."


- record_id: H262-021
  title: "4:2:0 coded_block_pattern decoding and residual-block selection"
  status: VERIFIED
  verified_date: 2026-08-14
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2000), official freely available consolidated edition"
  source_reference: "6.3.17.4; Annex B Table B.9"
  normative_force: SEMANTICS
  controlled_conclusion: >
    For 4:2:0 non-intra macroblocks with macroblock_pattern equal to 1,
    coded_block_pattern_420 is variable-length decoded to cbp using Table B.9.
    For block indices i=0 through 5, cbp bit (5-i) sets pattern_code[i]; a block
    is present when its pattern_code is 1.  Table B.9 therefore gives the
    controlled mappings CBP 32 = VLC 1010 (block 0 only), CBP 3 = VLC 001101
    (blocks 4 and 5), CBP 12 = VLC 10011 (blocks 2 and 3), and CBP 21 = VLC
    00011001 (blocks 1, 3 and 5).
  applicability: >
    Non-intra 4:2:0 macroblocks that signal macroblock_pattern and therefore
    carry coded_block_pattern_420.
  exceptions:
    - "The Table B.9 cbp=0 entry is explicitly marked as not to be used with 4:2:0 chrominance structure."
  conformance_effect: >
    A 4:2:0 decoder must use the decoded cbp bits to determine exactly which of
    blocks 0 through 5 contain coded residual block syntax.
  verification_method:
    type: TEST
    description: >
      Decode controlled Table B.9 VLCs with different luma/chroma bit patterns
      and verify that residual syntax is consumed and reconstructed only for the
      block indices selected by cbp.
  related_records: [H262-006, H262-018, H262-019, H262-020]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-14
      change: >
        Added from the official ITU-T H.262 (02/2000) text for generalized
        per-macroblock 4:2:0 residual block selection.

- record_id: H262-022
  title: "General frame-motion vector reconstruction from motion_code and motion_residual"
  status: VERIFIED
  verified_date: 2026-08-14
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2000), official freely available consolidated edition"
  source_reference: "7.6.3.1; Annex B Table B.10"
  normative_force: DECODE_PROCESS
  controlled_conclusion: >
    For each motion-vector component, r_size is f_code minus 1 and f is 2^r_size.
    If f is 1 or motion_code is zero, the differential is motion_code. Otherwise
    its magnitude is ((abs(motion_code)-1)*f)+motion_residual+1 and its sign is
    the sign of motion_code. The differential is added to the applicable PMV and
    wrapped into the component range [-16*f, 16*f-1]. Table B.10 supplies signed
    motion_code values from -16 through +16. For f_code=3 this reconstructed
    half-sample-unit range is [-64,+63].
  applicability: "Frame-based forward motion-vector reconstruction in the current non-scalable P-picture path."
  exceptions:
    - "Other motion_vector_count/motion_type cases select the applicable PMV as specified by H.262 before this component reconstruction."
  conformance_effect: >
    Legal positive and negative Table B.10 codes, residuals, predictor reuse and
    wraparound must produce the normative reconstructed component before reference addressing.
  verification_method:
    type: TEST
    description: "Exercise signed horizontal/vertical components, non-zero PMVs and f_code=3 residual bits and compare reconstructed vectors."
  related_records: [H262-003, H262-011, H262-012, H262-015, H262-016]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-14
      change: "Added for the generalized P-motion closure boundary."

- record_id: H262-023
  title: "4:2:0 chroma-vector division and exact half-sample interpolation arithmetic"
  status: VERIFIED
  verified_date: 2026-08-14
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2000), official freely available consolidated edition"
  source_reference: "Arithmetic operators; 7.6.3.7; 7.6.4"
  normative_force: DECODE_PROCESS
  controlled_conclusion: >
    For 4:2:0, each chroma motion-vector component is the corresponding luminance
    component divided by two using H.262 '/' integer division, which truncates
    toward zero. For prediction addressing, vector DIV 2 rounds toward minus
    infinity to select the integer reference position; a non-zero remainder is
    the half-sample flag. Horizontal or vertical half-sample prediction rounds
    (p0+p1)/2 to nearest, and two-dimensional half-sample prediction rounds the
    four-sample sum/4 to nearest, using the H.262 // operator.
  applicability: "Progressive 4:2:0 frame prediction with integer and half-sample forward vectors."
  exceptions: []
  conformance_effect: >
    Negative odd vectors must use floor integer addressing while chroma scaling
    itself truncates toward zero; interpolated prediction pels must use the exact
    prescribed neighboring samples and rounding.
  verification_method:
    type: TEST
    description: "Use signed odd horizontal/vertical vectors on distinct reference pels and compare luma and chroma prediction exactly."
  related_records: [H262-003, H262-004, H262-017, H262-022]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-14
      change: "Added exact arithmetic details needed by generalized half-sample P prediction."

- record_id: H262-024
  title: "Table B.14 non-intra Escape coefficient syntax"
  status: VERIFIED
  verified_date: 2026-08-14
  confidence: HIGH
  source_id: H262
  source_edition: "ITU-T H.262 (02/2000), official freely available consolidated edition"
  source_reference: "7.2.2.3; Annex B Table B.14"
  normative_force: SYNTAX
  controlled_conclusion: >
    In Table B.14 the Escape VLC is 000001. Escape is followed by a six-bit run
    and a twelve-bit two's-complement signed_level. The resulting run advances
    the scan-order coefficient position before signed_level is placed.
  applicability: "Escape-coded coefficients in coded non-intra blocks using Table B.14."
  exceptions:
    - "The forbidden signed_level values and coefficient-position overflow remain syntax/conformance errors."
  conformance_effect: >
    The decoder must consume the complete Escape payload, preserve the signed
    twelve-bit level, and apply the run before subsequent ordinary VLC/EOB syntax.
  verification_method:
    type: TEST
    description: "Decode a controlled Escape with non-zero run and negative signed_level, followed by ordinary EOB."
  related_records: [H262-010, H262-020]
  supersedes: []
  superseded_by: []
  revision_history:
    - date: 2026-08-14
      change: "Added for generalized sparse non-intra coefficient parsing."

```

## 10.3 CONFORMANCE-RECORD TEMPLATE

Use this template when adding another externally established atomic rule.

```yaml
record_id: "<DOMAIN>-<NNN>"
title: "One atomic controlled rule"
status: VERIFIED
verified_date: YYYY-MM-DD
confidence: HIGH

source_id: "<ID from CONTROLLED SOURCE CATALOG>"
source_edition: "Exact edition actually consulted"
source_reference: "Exact clause / section / table / figure / annex / page / command"

normative_force: "MUST | MUST_NOT | SHALL | SHALL_NOT | SHOULD | MAY | DEFINITION | CONSTRAINT | SYNTAX | SEMANTICS | TABLE_VALUE | INFORMATIVE"

controlled_conclusion: >
  Concise project-relevant statement of the externally defined rule.

applicability: >
  Exact conditions under which the rule applies.

exceptions:
  - "Only explicit source-defined exceptions."

conformance_effect: >
  Observable condition that must hold for the implementation to conform.
  Do not describe the chosen architecture here.

verification_method:
  type: "REVIEW | TEST | ANALYSIS"
  description: >
    How to check conformance without prescribing implementation architecture.

related_records: []
supersedes: []
superseded_by: []

revision_history:
  - date: YYYY-MM-DD
    change: "Initial entry."
```

---

# 11. EXCLUSIONS — PUT THESE ELSEWHERE

```yaml
not_for_this_file:
  - FPGA resource-usage decisions
  - FIFO depths chosen for timing
  - SDRAM allocation strategy
  - HPS/FPGA architecture
  - why a particular implementation is faster
  - failed experiments
  - build numbers
  - Quartus timing results
  - current task status
  - source-edit history
  - coding conventions
  - Linux deployment policy
  - compatibility goals not mandated by a controlled spec
  - inferred hardware behavior not confirmed by a controlled hardware document

belongs_here:
  - exact MPEG syntax and semantics
  - decoder conformance requirements
  - DVD-Video application rules
  - UDF/ISO9660 structures
  - optical-drive command definitions
  - CSS controlled requirements when authorized material is available
  - AC-3/MPEG/DTS coded-format definitions
  - CD/DVD disc interchange specifications
  - colorimetry/timing standards
  - official Linux optical-drive userspace API definitions
```

---

# 12. MAINTENANCE POLICY

1. **Never delete a still-applicable controlled source merely because the project no longer touches it every day.**
2. **Do not copy large portions of copyrighted standards into this repository.** Store concise conclusions and exact references.
3. **Do not fabricate clause numbers.** If the exact clause has not been checked, leave the record unverified.
4. **For licensed DVD/CSS books, record document identity and routing now; add clause-level rules only after authorized source access.**
5. **A newer generic standard does not automatically replace an application-pinned legacy version.**
6. **When implementing DVD-Video, check the DVD application spec first for restrictions, then use H.262/H.222.0 for the underlying MPEG syntax.**
7. **When implementing a USB optical drive through Linux, prefer MMC/Linux UAPI as the application-facing sources; USB transport specs are lower-layer references.**
8. **When a standard fact changes code, source comments may reference it as `STANDARDS_CONFORMANCE:<record_id>`.**
9. **Before each tagged release, audit all standards records added or modified since the previous release.**
10. **Future agents should scan Sections 0, 1, 8, and the Section 10 fast lookup index before beginning standards-sensitive work.**

---

# 13. SOURCE-CATALOG VERIFICATION SNAPSHOT

```yaml
catalog_verified_on: 2026-08-13

primary_official_catalog_pages_checked:
  - "ITU-T H.262 recommendation database"
  - "ITU-T H.222.0 recommendation database"
  - "ISO catalog for ISO/IEC 13818 Parts 1, 2, 3, 4, 5, 7"
  - "ISO catalog for ISO/IEC 11172 Parts 1, 2, 3, 4, 5"
  - "ATSC A/52 official standards page"
  - "ETSI TS 102 114 official repository"
  - "Ecma ECMA-167, ECMA-267, ECMA-119, TR/71, TR/112"
  - "IEC IEC 60908, IEC 62107, IEC 60958, IEC 61937"
  - "T10 MMC-6/SPC-5 project and drafts indexes"
  - "USB-IF USB 2.0 and Mass Storage document library"
  - "DVD CCA CSS official pages"
  - "Linux kernel CDROM userspace API documentation"
  - "ITU-R BT.601, BT.709, BT.470"
  - "HDMI Licensing Administrator specification pages"
  - "CTA-861 official CTA store page"

known_access_gaps:
  - "Authorized DVD FLLC Part 2 and Part 3 Format Books are not presently loaded into this reference."
  - "Confidential/restricted CSS technical specifications are not presently loaded."
  - "Exact clause-level citations for proprietary DVD/CSS behavior must wait for authorized source access."
```
