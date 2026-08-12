# Security Policy

MiSTer Media Player is an experimental FPGA project and is not currently intended for security-sensitive deployment. Even so, please report vulnerabilities responsibly.

## Supported versions

The project is pre-release. Security fixes are made only on the current `master` branch; older development phases are not maintained as supported releases.

## Reporting a vulnerability

Please avoid filing a public issue for a vulnerability that could meaningfully affect users or connected systems.

Use GitHub's private vulnerability reporting feature for this repository if it is available. If private reporting is unavailable, contact the repository owner through the contact method shown on the owner's GitHub profile and include enough detail to reproduce and assess the issue.

Useful information includes:

- affected commit;
- hardware/software environment;
- attack or failure conditions;
- reproduction steps;
- likely impact;
- any proposed mitigation.

Please do not include secrets, credentials, private media, or other sensitive data in a report.

## Scope notes

The current core primarily consumes local media data through the MiSTer framework. Future host-side filesystem, network, optical-drive, demux, DVD, and control functionality may expand the security surface and will require corresponding review as those features are implemented.
