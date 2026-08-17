# MiSTer-Media-Player

---

---

---

## Purpose

MiSTer-Media-Player is being developed as a simple, compatibility-focused media player for MiSTer. The immediate target is a standards-driven MPEG-2 Video / ITU-T H.262 decoder implemented primarily in FPGA logic. The long-term goal is a fully functioning DVD player core that can play commercial disks from .iso files, a DVD folder structure, or directly from a USB-attached DVD reader. Another project called MiSTer-Media-Player-Audio is being develevoped in parallel to handle standalone OGG, MP3, and FLAC files and will be integrated back into the MiSTer-Media-Player once complete.

---

## Standards

- ITU-T H.262 / ISO/IEC 13818-2 is normative for video syntax/decoding.

- ITU-T H.222.0 / ISO/IEC 13818-1 is normative for systems/program streams.

- Use ISO-8601 timestamps with the local UTC offset. Timezone is America/Phoenix.

- When needing to look up reference material, use core-standards.md as an authoritative source when attempting to lookup anything that could be considered a standard, conformance, specification, etc. as opposed to looking it up online.

- If you are not able to find the information you need by consulting core-standards.md, look up the standard online you trust and make an educated determination if you would like to add it to your core-standards.md document following existing syntax and formatting for future reference.

- If a more recent or otherwise more valid source is discovered during your online research and it is not documented in core-standards.md, you are to notify the user.

- Diagnostic implementation limits must not be described as standard limits.

- Respect all all standard licensing and attribution conventions.

---

## AI Agent Recovery Policy

Read this core.md file first. Treat it and all the directives in it as the sole authoritative source for recovery procedure, standing workflow, and agent behavior. All directives in the document have the same priority, not just in this section. Read core-log.md second as historical engineering/build/transcript evidence. Treat core.md as RESTRICTED, authoritative project core memory. Do not edit it automatically for any reason. Only edit core.md if the user explicitly asks for it.

---

## Build Enviroment

- The github repository for this project is: https://github.com/aquasock/MiSTer-Media-Player.git

- The github repository for the MiSTer-Media-Player-Audio project is:

- Always follow the existing changelog convention found in core-log.md

- The users local githib repository must always stay up to date with the online repository.

- core-log.md is the authoritative source for current project status. The github repository is the backup source.

- The tar.gz archives stored in the "archived_results" folder are not to be referenced unless approval from the user is given first.

- a clean build from a cloned github source from master is required for all releases.

- Do not create branches if possible. always work off of master unless otherwise instructed.

- User is building on Kubuntu 26.04 LTS with Quartus Prime v17.0.2 Lite.

---

## Agent Behavior

- Keep project conversation limited to project enviroment.

- No need to be polite when speaking, Communicate as you would in a standard engineering enviroment.

- Assume all user commands are run from the source root.

- Before approval, limit work to evidence gathering, log interpretation, problem scoping, and defining the proposed commit boundaries and validation plan. Do not proceed into solution design or implementation reasoning.

- After the user approves the proposed plan, carry out the approved development cycle: determine the implementation, make the source changes, commit the changes to GitHub master, update core-log.md, and report the results.

- Split changes further only when risk, standards uncertainty, diagnostic isolation, or new evidence makes a smaller boundary materially safer.

- If new findings would materially change the approved plan, stop and obtain user approval for the revised plan before continuing.

- Accelerated development is the default cadence. Plan each development cycle around a materially useful hardware-validation boundary rather than deliberately small micro-steps. As a guideline, combine adjacent low-risk changes into increments roughly twice the size of the earlier conservative flow when they share one clear proof boundary.

- Generated binary regression artifacts and diagnostic tools the user is intended to run such as ffmpeg generated files should normally be produced by deterministic scripts committed under tools/streams/ and generated locally by the user, rather than requiring the agent to commit the binary itself.

- Treat core-log.md as a ring buffer. Only 20 of the most recent entries are ever allowed. Roll over to "001" when "999" is reached.

- The folder labeled ".ai" on the github repositories root is your core project folder and contains your core directives, (core.md) running project memory, (core-log.md), and standards library (core-standards.md)

- Use the commit message "(current\_short commit) core-log.md update" for all updates you make to core-log.md. 

- Use the commit message "(current\_short commit) core.md update" for all updates you make to core.md. 

- Use the commit message "(current\_short commit) core-standards.md update" for all updates you make to core-standards.md. 

- "current_short_commit"" means the abbreviated SHA of the current github repository.Metadata-only .ai commits do not change this value for that development cycle.

---

## Agent Response Loop

- When responding to the user, follow the following chain of events:

1. Record the current time in a file on the local github root named "response_timestamp.txt". If the file already exsits, replace it.

2. Continue normal agent "Thinking" process and respond to the user as normal.

3. If the recorded time in "response_timestamp.txt" is greater than 1 minute from the current time, send the user an email notifying them that your response is ready.

4. Await user input.

5. Repeat.

---

## Target Enviroment

- Treat the user's current MiSTer hardware configuration as the standard development target unless the user says otherwise.

- The user's standard target is as follows:

DE10-Nano-compatible Cyclone V SoC MiSTer system

Linux:\
Kernel: Linux MiSTer 5.15.1-MiSTer\
Build:  Wed Apr 2 20:01:54 CST 2025

HPS CPU:\
ARM Cortex-A9\
2 cores\
ARMv7 little-endian\
CPU range: 400 MHz - 1.2 GHz

HPS RAM visible to Linux:\
MemTotal: 504096 kB\
Approx. 492 MiB Linux-visible

HPS <-> FPGA Bridges:\
Lightweight HPS-to-FPGA: present\
HPS-to-FPGA:             present\
FPGA-to-HPS:             present

Ethernet:\
Controller: Cyclone-V HPS DWMAC1000\
PHY: Micrel/Microchip KSZ9031\
Link: 1 Gbit/s Full Duplex

I2C:\
m41t81  @ 0x68   - operational / supplies rtc \
\
Power:\
Idle Current: \~1.1A

---

## Standard Workflow:

1. Review the available build and test logs, identify the observed failures or required work, and prepare a proposed plan of action for the next GitHub commits. 

2. Update core-log.md with your proposal and await user approval.

3. You will then make changes to the local github source code directly that is aligned with your proposed changes in core-log.md.

4. You will then commit the changes to the online repository with a commit message that follows previous agents commit message conventions. This will become the next builds official commit hash.

5. I will then build the binary and run any diagnostic tests you requested.

6. I will inform you of my test results and you will inspect the local build logs.

7. Check the MiSTer-Media-Player-Audio project's latest commit on github and verify that there are no conflicts with the MiSTer-Media-Player's functionality or later integration with MiSTer-Media-Player-Audio.

8. Repeat.

---

## Versioning

- This project uses Semantic Versioning for GitHub releases.

- The first release is version 0.1.0.

- Git tags and GitHub releases use a leading `v`, for example `v0.1.0`, while the human-readable project version is `0.1.0`.

- While the project remains pre-1.0, increment MINOR for each new hardware-proven development milestone that adds meaningful capability (0.1.0 -> 0.2.0 -> 0.3.0).

- Increment PATCH for fixes or release corrections that do not constitute a new milestone (0.1.0 -> 0.1.1).

- Reserve 1.0.0 for a future user-ready compatibility baseline explicitly approved by the user.

- Development commits between published releases do not receive Semantic Version numbers or Git version tags. They belong to Unreleased until a hardware-proven milestone is accepted for release, at which point the next Semantic Version is assigned.

---

## Releasing

- Record every published version/tag/release boundary in `core-log.md`.

- GitHub release title should be `MiSTer Media Player vX.Y.Z`.

- Keep `CHANGELOG.md` in Keep-a-Changelog style: maintain an `Unreleased` section during development; at release, move accepted milestone changes under a `## [X.Y.Z] - YYYY-MM-DD` heading and start a fresh `Unreleased` section.

- Release notes should summarize the milestone, supported/known limitations, hardware validation performed, and any important timing/resource information.

- The agent is responsible for source/version metadata, changelog/release notes during release.

- Mark pre-1.0 releases as pre-release on GitHub unless the user explicitly decides otherwise.

- MiSTer binary naming follows the MiSTer core convention rather than Semantic Versioning: use `MediaPlayer_YYYYMMDD.rbf` for the actual core binary, where the date is the release/build date.

- Do not rename the RBF to `MediaPlayer_vX.Y.Z.rbf`. The user is responsible for building and packaging the binary release artifacts.

1. Have the user peform a full regression test suite with a clean/from-scratch Quartus build and verify the results.

2. Update the README.md and CHANGELOG.md on the projects github and commit the change.

3. Have the user create the annotated/version tag and GitHub Release from that exact commit so source, release notes, and binary package are reproducible.

4. Finish pushing the release onto github.

---
