# Reviewed build inputs

## Silicon Labs Configurator (SLC)

Supply `slc_cli_linux.zip` in this build directory before building. The Dockerfile
checks it before extraction and does not replace it with a network download.
The accepted archive is SLC 5.11.0.0 (215063443 bytes), with SHA-256:

```
5fc88e5f7e3a782a9181716bf173285d4794ea6d2282dde0c992179e3ab955f8
```

This is the archive used in the validated Trixie builds with SDK
`da661283f301b53eec04d1016009e60bc7e34a1f` and Java 21. Its embedded SLC changelog
identifies 5.11.0.0 and the Java 21 transition. The recorded acquisition source is
[Silicon Labs](https://www.silabs.com/documents/login/software/slc_cli_linux.zip).
That URL is mutable: it is a retrieval location, not a version guarantee. If it
serves different bytes, obtain the reviewed version from a trusted retained copy
or deliberately validate an update; do not bypass or automatically refresh the
checksum. The checksum is a reviewed content pin, not a vendor signature.

For an intentional update, establish the official source and release identity,
review SDK/Java compatibility and licensing, update the checksum and version in
this document and Dockerfile together, and repeat SLC generation and Zigbeed
compilation for the supported architectures. Retain the acquisition provenance
and results. Do not commit the binary archive or private download credentials.

These controls preserve the selected generator. They do not make APT packages,
all other build inputs, or the complete image byte-for-byte reproducible.

## mDNSResponder

The bootstrap patch retains Apple's mDNSResponder-1790.80.10 release, resolved
to commit `8769ab51605e465425d33d757f602ce5905ca639`. It downloads the commit archive
over certificate-verified HTTPS with bounded network retries and verifies SHA-256
`fc75ffcb6f67634d8d1a10272317f72ec6d211ef03125c7c181edfc1d0ffee4e`
before extraction. The source is from Apple's official GitHub repository; the
checksum is a reviewed content pin, not a vendor signature. A changed response,
HTTP failure or certificate failure must stop the build rather than bypass
verification. For an intentional update, verify the official tag/commit, review
release compatibility and the existing OpenThread patches, update the archive
pin, then build and test the resulting mDNS integration.

## Acquisition regression checks

From this directory on a Docker-enabled Linux host, with the reviewed SLC archive
present (read-only mounts below):

```sh
docker build -t local/otbr-build-input-tests tests/build-inputs
docker run --rm \
  -v "$PWD:/product:ro" \
  -v "$PWD/slc_cli_linux.zip:/slc.zip:ro" \
  local/otbr-build-input-tests python3 /product/tests/build-inputs/check.py
```

The fixture applies the patch to the pinned vendor bootstrap and executes its
actual download/checksum commands. It verifies a real HTTPS download, checksum
failure before extraction, the Dockerfile's valid/incorrect/missing SLC check,
untrusted TLS rejection and HTTP failure. It uses temporary files and a local
synthetic TLS server; it does not contact Home Assistant or start OTBR. These
checks do not replace full image, generator or radio validation.
