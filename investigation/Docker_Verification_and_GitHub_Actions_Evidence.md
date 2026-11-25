# Docker Verification Results and GitHub Actions Scan Evidence

**Project:** `gen-pipeline-runner-nf`  
**Finding:** CVE-2017-17740 (OpenLDAP)  
**Investigator:** Bhavya  
**Evidence collated:** 25 November 2026  
**Status:** Preliminary investigation; **not** an approved false-positive/not-affected disposition.

## 1. Reported security finding

| Field | Value from reviewed finding/screenshots |
|---|---|
| Vulnerability | CVE-2017-17740 |
| Scanner | Trivy (finding presented in the security dashboard) |
| Affected package | `libldap2` |
| Package version | `2.6.10+dfsg-1` |
| Displayed OS | Debian 13.8 |
| Displayed scan target | `ourfuturehealth/gen-pipeline-runner-nf:local` |
| First seen | 15 October 2026 |
| False-positive request | Pending; submitted 20 November 2026 |

**Scope warning:** The locally inspected Docker image is **different** from the historical GitHub Actions images. The local filesystem results below do **not** prove what was present in the image originally scanned on 15 October.

## 2. Local Docker image identity

**Inspected image:** `ourfuturehealth.azurecr.io/ourfuturehealth/gen-pipeline-runner-nf/pipeline_runner:0.0.39-a4`  
**Platform:** `linux/amd64`  
**Local image ID/reported digest:**

```text
sha256:e6ca810d7a582a97322b5504cf1a0b21ddb1bfee241f63997f1f5e907ed96304
```

Commands used:

```powershell
docker images
docker image inspect e6ca810d7a58 --format '{{json .RepoDigests}} {{.Os}}/{{.Architecture}}'
docker image inspect e6ca810d7a58 --format '{{.Id}}'
docker image inspect e6ca810d7a58 --format '{{index .RepoDigests 0}}'
```

The above ID identifies the local image. It must **not** be treated as matching a historical build simply because tags or package versions overlap.

## 3. Docker verification — executed commands and observed findings

### A. Installed LDAP packages

```powershell
docker run --rm --entrypoint /bin/sh e6ca810d7a58 -c 'dpkg-query -W "*ldap*" "slapd*" 2>/dev/null || true'
```

**Observed:** `libldap2:amd64` version `2.6.10+dfsg-1`; also `libldap-common` and `libnet-ldap-perl` (versions not captured in the handover). The reported `libldap2` version is installed in the **local** image.

### B. OpenLDAP server package

An explicit package-status check returned:

```text
SLAPD PACKAGE NOT INSTALLED
```

The earlier `command -v slapd` check produced no path. This establishes that a standard Debian-installed `slapd` was not identified in the local image; it does not exclude an unusual custom build or renamed executable.

### C. Searches for affected module and overlay

Commands executed included:

```powershell
docker run --rm --entrypoint /bin/sh e6ca810d7a58 -c 'find /usr /opt -type f -iname "*nops*" 2>/dev/null'
docker run --rm --entrypoint /bin/sh e6ca810d7a58 -c 'find /usr /opt -type f -iname "*memberof*" 2>/dev/null'
docker run --rm --entrypoint /bin/sh e6ca810d7a58 -c 'find /usr /opt -type f -name "slapd" 2>/dev/null'
```

Additional `find /` searches for the same names were attempted. The successful searches returned **no matching file paths**; at least one `/usr` and `/opt` search returned process exit code `0`. A combined search initially encountered shell-quoting errors and is **not** counted as valid absence evidence.

**Observed:** No file named like `nops`, `memberof`, or `slapd` was identified in the searched locations of the locally inspected image. File-name searches alone do not rule out statically linked or nonstandard components.

### D. Library file ownership

```powershell
docker run --rm --entrypoint /bin/sh e6ca810d7a58 -c 'dpkg -L libldap2'
```

**Observed:** `libldap.so.2` and `liblber.so.2` (and their versioned files) in `/usr/lib/x86_64-linux-gnu/`. No `slapd` or `nops` file appeared among `libldap2`'s listed package files.

### E. Package dependencies

```powershell
docker run --rm --entrypoint /bin/sh e6ca810d7a58 -c 'apt-cache rdepends --installed libldap2'
docker run --rm --entrypoint /bin/sh e6ca810d7a58 -c 'apt-cache depends libldap2'
```

**Observed installed reverse dependencies:** `dirmngr`, `libcurl4t64`, `libcurl3t64-gnutls`.

**Observed dependencies of `libldap2`:** `libc6`, `libsasl2-2`, `libssl3t64`; `libldap-common` listed as recommended.

**Interpretation:** Other packages depend on the client library; this explains why retaining `libldap2` may be necessary. It does **not** establish which Dockerfile `RUN` instruction first installed it.

### F. Image history

```powershell
docker history --no-trunc e6ca810d7a58
```

**Observed:** Debian Trixie/Python base components and APT-based installation layers. The exact layer that introduced `libldap2` was **not** conclusively identified.

## 4. GitHub Actions scan/build evidence

### 15 October 2026 — `main`

- Repository: `ourfuturehealth/gen-pipeline-runner-nf`
- Historical Actions run ID supplied in investigation: `38705794807`
- Workflow: `Run invicti scans`; job `scan`
- Dockerfile: `docker/nf-az.Dockerfile`
- Build action: `docker/build-push-action@v7`
- Build settings: `push: false`, `load: true`
- Built/tagged image: `ourfuturehealth/gen-pipeline-runner-nf:local`
- Build log's image ID:

```text
sha256:7283a949a2d7c73edb18cf85a6aa18ddacc5376cb160150c4905cb048c08754c
```

- Historical OS reported by a later comparison of raw scan/build logs: Debian **13.7**.
- Later analysis of the raw logs reported `libldap2:2.6.10+dfsg-1` in the historical scan evidence. **The source log excerpts should accompany this report when submitted.**

### 25 November 2026 — `GE-213-add-gen-tracking`

- Workflow: `Run invicti scans` / container scan
- Docker image built under the same `gen-pipeline-runner-nf:local` tag, but a **different image ID**; reported prefix `sha256:74130c68…` (full hash not captured here).
- OS reported by cross-branch log comparison: Debian **13.8**.
- Reported package: `libldap2:2.6.10+dfsg-1`.
- The branch scan passing/succeeding does not mean that Trivy reported zero vulnerabilities.

### 25 November 2026 — `dev`

- Logs reviewed were for Copilot review, **not an equivalent Trivy container scan**. Do not count this as evidence that the CVE is absent or resolved.

### Cross-branch interpretation

| Check | `main` (15 Oct) | `GE-213-add-gen-tracking` (25 Nov) |
|---|---|---|
| Image tag | `gen-pipeline-runner-nf:local` | `gen-pipeline-runner-nf:local` |
| Image ID | `7283a949…` | `74130c68…` |
| Debian version in reviewed log comparison | 13.7 | 13.8 |
| `libldap2` | `2.6.10+dfsg-1` reported | `2.6.10+dfsg-1` reported |
| Exact image filesystem inspected? | **No** | **No** |

There were no additional `main` runs after October 15 according to the investigator's GitHub Actions check; other branches did run. **It remains unverified whether a feature-branch scan updated the existing Invicti finding.**

### Important SHA distinction

The GitHub Actions `.dockerbuild` artifact's SHA256 checksum is **not** the Docker image ID. The image IDs above came from Docker build output; do not substitute the artifact checksum.

## 5. What is established versus still missing

### Established

1. The local `0.0.39-a4` image contains `libldap2` matching the reported version.
2. Standard `slapd` package installation and matching `nops`/`memberof` module files were **not found** in checks of that local image.
3. Several installed packages depend on `libldap2`.
4. The October `main` and November feature-branch builds used the same human-readable local tag but **different image IDs**.
5. The reviewed scan/build evidence associates the October and November builds with different Debian minor versions while reporting the same `libldap2` version.

### Not established

1. That the *exact historical scanned image* lacks vulnerable OpenLDAP server components.
2. Which particular imported scan is represented by the current Invicti record and why it displays Debian 13.8 together with `main`.
3. Whether the vulnerable OpenLDAP functionality is included through custom or statically linked code in any historical artifact.
4. Whether a not-affected/false-positive classification has been approved or propagated to the correct system.
5. That merging `GE-213-add-gen-tracking` into `main` will clear the CVE. A merge alone does not guarantee that.

## 6. Recommended next investigation steps

1. **Correlate the finding with an actual scan record:** identify scan ID, scan time, source branch and image ID in Kondukto/Invicti or the raw imported Trivy report.
2. **Validate the correct historical artifact:** obtain the exact image or a provenance-backed reproduction and check package inventory, custom components and relevant server/module configuration. If unavailable, explicitly state the evidence limitation.
3. **Record vendor applicability evidence:** capture the relevant Debian/OpenLDAP advisory and its applicability to the built binary package/version; distinguish source-package listing from actual vulnerable module presence.
4. **Write a conclusion with a confidence level:** detection root cause, conditions required for exploitation, evidence supporting/not supporting impact, and unresolved checks.
5. **Request AppSec review** of the already pending false-positive/not-affected request; use the organization's approved system and workflow for recording the disposition.
6. **Verify a subsequent scan** after any approved exception or application-team changes. Do not assume merging the branch alone resolves the finding.

## 7. Proposed concise note for Tory and Ross

> I've reproduced the installed `libldap2:2.6.10+dfsg-1` package in the local `pipeline_runner:0.0.39-a4` image and checked the Debian package inventory and filesystem. `slapd` is not installed there, and I couldn't locate `nops` or `memberof` module files. `libldap2` is also a dependency of other installed packages.
>
> I reviewed the October 15 `main` security build and November 25 `GE-213-add-gen-tracking` security build. They have different image IDs and Debian versions (13.7 versus 13.8), but both report the same `libldap2` version. The current Invicti finding displays Debian 13.8, so its association with the underlying imported scan still needs confirmation.
>
> The checks so far support a possible *not affected* assessment, but they were performed on a different local image, not the exact historical scan artifact. Could you review the findings and advise what further validation is needed for the pending false-positive request? I can share the Docker results and scan logs.

---

**Evidence attachment checklist:** local Docker command screenshots/terminal outputs; 15 Oct `main` raw Actions logs; 25 Nov feature-branch scan logs; current CVE finding screenshot; official Debian advisory. This report summarizes earlier-reviewed outputs; it is **not a substitute for attaching the original raw evidence**.
