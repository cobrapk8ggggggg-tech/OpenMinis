# iOS build and size audit

This branch starts at upstream OpenMinis 1.14, commit
`b4c0661d5631ebab4d1a2e6f3fd4c805d4030a6c`.

The device build uses upstream app code and native build scripts unchanged.
No app extension, framework, Linux rootfs, language or asset is removed.
The only additions are the audit workflow, measurement helpers and this report.
Simulator-specific SDK selection is applied to the native scripts inside its
separate runner workspace; no mock Linux implementation is substituted.

## Measurements

The workflow produces a Release device archive and an unsigned IPA. The JSON
report records exact package bytes, unpacked app bytes, per-component sizes,
the largest individual files, included extensions and the package SHA-256.
MB means 1,000,000 bytes; MiB means 1,048,576 bytes.

A simulator archive is measured separately and is not a device-size estimate.
The simulator job attempts installation, launch, a process check after 20 seconds
and a screenshot. A build alone is not reported as a successful launch.

## Comparison limits

Apple metadata retrieved on 2026-10-19 reports version 1.15 with a fileSizeBytes
value of 416,843,776 (416.84 MB / 397.53 MiB). The public upstream main branch
is version 1.14, so this is not a same-version binary comparison.

An unsigned ZIP-compressed IPA is not an App Store download-size measurement.
Apple processing, encryption, device-specific thinning and resources may change
the distributed size. The unpacked app also excludes user data and the extracted
Linux environment created at runtime.

Version 1.15 release notes mention AOJIT precompiled execution images. Those
images are not present in the public 1.14 source snapshot. Their size contribution
cannot be established without inspecting the corresponding 1.15 binary.

## Reproduce

The workflow is `.github/workflows/ios-size-audit.yml`. Both jobs run on a real
GitHub-hosted macOS ARM64 runner with Xcode. Build outputs are uploaded for
14 days. A locally built IPA remains unsigned and cannot be directly installed
on a physical iPhone without an appropriate signing process.

## Observed device builds

The 1.14 full device IPA is 64,160,117 bytes; its unpacked app is
133,496,473 bytes. The user's 1.12 Arabic branch rebuilt successfully using
its original workflow: the IPA is 49,760,052 bytes; the unpacked app is
92,725,773 bytes. That older workflow removes all embedded extensions.

See [the Arabic comparison](comparison-ar.md), [package metrics](package-comparison.json)
and [translation metadata](branch-comparison.json) for the differences.

The simulator source compiled successfully after SDK selection and a clean
LAME rebuild. Initial runtime attempts did not pass: the full-entitlement
attempt was killed by macOS taskgated with `CODESIGNING / Taskgated Invalid
Signature`. A standalone workflow reuses that already-built artifact to test
minimal simulator entitlements. Device build success is independent of the
simulator launch result.


Final simulator outcome: **launch check failed**. The minimal-entitlement
runtime retry returned a PID but was killed before the 20-second liveness
check with `CODESIGNING / Invalid Page` in `dyld_sim` while loading dependencies.
Both crash reports and `verification-result.json` are retained. No app UI,
model call, or physical iPhone execution is claimed as verified.

The standalone runtime workflow reuses the simulator artifact and does not
rebuild it. The combined build workflow can therefore have a failed overall
conclusion even though its device archive and simulator compilation succeeded.
