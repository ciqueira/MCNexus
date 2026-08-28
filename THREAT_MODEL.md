# Threat Model

This document describes what MCNexus's licensing protections are designed to
stop, what they explicitly do not attempt to stop, and why. It complements
[SECURITY.md](SECURITY.md) (how to report a vulnerability) and
[PRIVACY.md](PRIVACY.md) (what data is collected and why).

## What this protects against

- **Casual, unintentional oversharing.** A license is bound to a device
  through a hardware-derived identifier, so copying an application's local
  data folder, a license file, or an activation receipt to a second machine
  does not let that second machine start rendering — it has to activate its
  own seat, which counts against the license's activation limit.
- **Tampering with a license record in transit or at rest.** Activation
  records exchanged with the licensing service are cryptographically signed;
  a modified or forged record fails verification instead of being honored.
- **Extending an offline period by manipulating the system clock.** MCNexus
  tracks the most recent trusted time it has observed and rejects a clock
  that jumps backward beyond a small tolerance, closing the most direct way
  to keep an expired license appearing valid.

## What this does not protect against

- **A determined attacker with full access to the binary and the machine.**
  Reverse engineering, patching, or otherwise disabling the licensing check
  inside a copy of the software the attacker fully controls is not something
  any client-side check can prevent — this is a well-known limit of all
  offline-capable licensing, not specific to MCNexus. We do not invest in an
  arms race against this; see "What we choose not to do" below.
- **A user who never intended to circumvent anything, but hits a false
  positive.** Where a check could either wrongly deny a legitimate user or
  wrongly allow an illegitimate one, we bias toward not interrupting real
  work — for example, a lost connection to the licensing service is treated
  as "try again later," never as "license revoked."

## What we choose not to do, on purpose

- No attempt to detect or respond to a debugger, virtual machine, or
  disassembler attached to the process. These signals are unreliable, break
  on legitimate setups (CI, sandboxed hosts, some render farms), and do not
  change the outcome against the attacker described above.
- No visible watermark, degraded output, or other punitive behavior when a
  license check fails during rendering. A denied render produces neutral,
  unmodified output through the same code path a licensed render uses,
  rather than a separate path that would only ever run for someone without a
  seat — and would therefore be the least-tested code in the product.

## Data involved

The identifiers used to bind and verify a license are described in
[PRIVACY.md](PRIVACY.md). In short: the raw hardware identifier never leaves
the device — only a one-way hash of it does, and that hash cannot be
reversed back into the original identifier.

## Reporting an issue

If you believe you have found a way to bypass a licensing check that this
document lists as protected against, see [SECURITY.md](SECURITY.md) for how
to report it privately.
