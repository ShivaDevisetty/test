# GG-353 — OpenJDK / eMudhra Certificate Verification

## Purpose

Validate whether a release of the shared `gen-pipeline-runner-nf` Docker image trusts the affected eMudhra G3 certificate chain. This runbook reproduces the read-only checks performed against development image `pipeline_runner:0.0.39-a4` and provides a repeatable process for Rob's upcoming release.

**Scope:** Image-level validation first; consumer workflow rollout and running workloads must be verified separately. **Do not modify or remove certificates, push a Docker image, or close GG-353 solely because a test endpoint is rejected.**

## Background and established findings

- Source repository: `ourfuturehealth/gen-pipeline-runner-nf`.
- Previously tested image: `ourfuturehealth.azurecr.io/ourfuturehealth/gen-pipeline-runner-nf/pipeline_runner:0.0.39-a4`.
- Rob confirmed `0.0.39-a4` was a development build **not deployed anywhere** when he reported it.
- The runner image is shared among multiple Nextflow consumer repositories. At the time of Rob's report, consumers referenced versions `0.0.20`, `0.0.26`, `0.0.34` and `0.0.37`, depending on repository/branch. These are *workflow references*, not proof of a particular running job.
- For `0.0.39-a4`, we observed Debian 13, OpenJDK 21.0.13, installed `ca-certificates` and `ca-certificates-java`, and Java's default `cacerts` symlink pointing to `/etc/ssl/certs/java/cacerts`.
- The inspected default Java truststore contained emSign C1, C3 and G1 certificates but no text matches for `emSign.*G3` or `AAA Certificate Services`.
- A Java HTTPS test against Rob's test endpoint returned **`TLS_REJECTED` / `PKIX path building failed`**. This demonstrates the Java client rejected the chain presented at test time; it is **not**, by itself, proof about other images, workloads, or every compromised certificate.

## Requirements

- Windows PowerShell; Docker Desktop running with Linux containers.
- Azure CLI installed and signed in; permission to pull from the organization's Azure Container Registry (ACR).
- Permission to access the externally hosted test endpoint from a temporary container.
- Rob's **new image reference and immutable digest** (plus source commit, if available).
- The existing `CheckTLS.java`, or create it using the instructions below.

All commands below run in **Windows PowerShell**, not inside an interactive Linux shell, unless explicitly stated.

## 1. Authenticate and select the image

```powershell
docker info
az account show --output table
az acr login --name ourfuturehealth
```

Replace `NEW_TAG` with the release tag Rob supplies. Prefer an immutable digest (`@sha256:...`) if one is provided. Do **not** paste a placeholder and assume it is a real release.

```powershell
$Image = "ourfuturehealth.azurecr.io/ourfuturehealth/gen-pipeline-runner-nf/pipeline_runner:NEW_TAG"
docker pull $Image
docker image inspect $Image --format '{{json .RepoDigests}}'
```

Record the actual image digest for comparison with the consumer workloads.

## 2. Inspect the operating system and Java

```powershell
docker run --rm --network none --entrypoint cat $Image /etc/os-release
docker run --rm --network none --entrypoint java $Image -version
```

If the new image remains **Debian-based**, inspect its certificate packages:

```powershell
docker run --rm --network none --entrypoint dpkg-query $Image -W ca-certificates ca-certificates-java
```

The previous image returned `ca-certificates 20250419+deb13u1` and `ca-certificates-java 20240118`. **Do not require identical versions** for a new release; assess patch status against the new release's OS and advisory. Ubuntu or non-Debian images require different package checks.

## 3. Verify the Java truststore

Inspect the Debian system-managed store and Java's resolved truststore path:

```powershell
docker run --rm --network none --entrypoint ls $Image -l /etc/ssl/certs/java/cacerts
docker run --rm --network none --entrypoint /bin/sh $Image -c 'readlink -f "$(dirname "$(readlink -f "$(command -v java)")")/../lib/security/cacerts"'
```

In our earlier Debian OpenJDK 21 image the Java path resolved to `/etc/ssl/certs/java/cacerts`. The command is intentionally based on `java`'s resolved location, rather than hard-coding version `21`.

Check that `keytool` can read the default store:

```powershell
docker run --rm --network none --entrypoint keytool $Image -list -cacerts -storepass changeit
```

**Search for relevant certificate names:**

```powershell
docker run --rm --network none --entrypoint /bin/sh $Image -c 'keytool -list -cacerts -storepass changeit | grep -i emsign'
docker run --rm --network none --entrypoint /bin/sh $Image -c 'keytool -list -v -cacerts -storepass changeit | grep -i -E "emSign.*G3|AAA Certificate Services"'
```

No output on the second search means only that **those strings were not found**. This does not replace the exact SHA-256 fingerprint comparison with the affected certificates from the advisory. Other G3 roots (e.g., unrelated DigiCert roots) are not equivalent to the affected emSign G3 roots. Do not remove legitimate C1, C3, or G1 roots based only on their names.

### Optional: check a specific certificate fingerprint

For an alias confirmed to exist (example from our earlier image):

```powershell
docker run --rm --network none --entrypoint keytool $Image -list -v -cacerts -storepass changeit -alias 'debian:emsign_root_ca_-_g1.pem'
```

Compare the SHA-256 fingerprints of **the affected certificate(s)** from the actual advisory with the truststore's fingerprints. Do not substitute the above G1 example for an affected G3 fingerprint.

## 4. Check for custom truststores in the image

Inspect Java-related image environment settings (review locally before sharing, as variables may expose secrets):

```powershell
docker image inspect $Image --format '{{range .Config.Env}}{{println .}}{{end}}' | Select-String 'JAVA|JDK|TRUST|CERT'
```

Search common locations (read-only and not exhaustive):

```powershell
docker run --rm --network none --entrypoint /bin/sh $Image -c 'find /usr/lib/jvm /opt /src -type f -name "*.jks" 2>/dev/null'
docker run --rm --network none --entrypoint /bin/sh $Image -c 'find /usr/lib/jvm /opt /src -type f -name "*.p12" 2>/dev/null'
docker run --rm --network none --entrypoint /bin/sh $Image -c 'find /usr/lib/jvm /opt /src -type f -name "*.pfx" 2>/dev/null'
docker run --rm --network none --entrypoint /bin/sh $Image -c 'find /usr/lib/jvm /opt /src -name "cacerts" 2>/dev/null'
```

No matches in these directories do **not** rule out runtime-mounted stores, JVM command-line overrides, or environment injected by a consuming workflow.

## 5. Java TLS validation against Rob's endpoint

The Java client must validate the TLS chain with **Java's default SSL configuration**; it must not disable hostname verification, use a trust-all manager, or install a custom CA. The test endpoint referenced in GG-353 was:

`dv-g3b-emudhra.we-have-a-problem.com`

Confirm the endpoint is still presenting the intended G3 chain when performing the test. The endpoint could change over time.

### Create CheckTLS.java only if it does not already exist

Run from PowerShell. This creates a local file **outside the Git repository**:

```powershell
$TestDir = Join-Path $HOME 'DockerSecurityCheck'
New-Item -ItemType Directory -Force -Path $TestDir | Out-Null
@'
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLHandshakeException;
import java.net.URI;

public class CheckTLS {
    public static void main(String[] args) throws Exception {
        String host = "dv-g3b-emudhra.we-have-a-problem.com";
        try {
            HttpsURLConnection connection = (HttpsURLConnection)
                URI.create("https://" + host).toURL().openConnection();
            connection.setConnectTimeout(10000);
            connection.setReadTimeout(10000);
            connection.setInstanceFollowRedirects(false);
            connection.connect();
            System.out.println("TLS_ACCEPTED");
            connection.disconnect();
        } catch (SSLHandshakeException e) {
            System.out.println("TLS_REJECTED: " + e.getMessage());
        } catch (Exception e) {
            System.out.println("TEST_INCONCLUSIVE: " + e);
        }
    }
}
'@ | Set-Content -Path (Join-Path $TestDir 'CheckTLS.java') -Encoding ascii

Test-Path (Join-Path $TestDir 'CheckTLS.java')
```

`True` indicates the file exists. Do not type Java `import`, `class`, or `System.out.println` lines directly at a PowerShell prompt. If using a here-string, the opening `@'` and closing `'@` delimiters are essential.

### Run the test

**Only if access to the public test hostname is approved:**

```powershell
docker run --rm --network bridge --entrypoint java -v "${HOME}\DockerSecurityCheck:/test:ro" $Image /test/CheckTLS.java
```

| Output | Interpretation |
|---|---|
| `TLS_REJECTED` with `PKIX path building failed` | Java rejected the server's current certificate path. Supports the mitigation claim **if** the endpoint still presents the affected G3 chain. |
| `TLS_ACCEPTED` | Java accepted the presented certificate; investigate whether the chain and expected trust configuration are correct. |
| `TEST_INCONCLUSIVE` or compilation failure | Test did not establish certificate behavior. Resolve the error before drawing conclusions. |

The previous image `0.0.39-a4` returned a `TLS_REJECTED` / `PKIX path building failed` result. This result must **not** be copied forward as evidence for the new release without rerunning the test.

## 6. Validate consumer rollout separately

Rob explained that the runner is referenced from the **consumer repositories' workflow files**, and workloads can be Kubernetes Jobs. It is not a single Azure Container App. Therefore, finding zero Azure Container Apps or Container Apps Jobs was **not** evidence that the runner was unused.

For each consumer in scope, verify:

1. A PR/commit updates its workflow to the new runner reference.
2. The new reference resolves to the release digest verified above.
3. Its runtime does not override Java's default store using `-Djavax.net.ssl.trustStore`, `JAVA_TOOL_OPTIONS`, `JDK_JAVA_OPTIONS`, mounted certificates, or similar settings.
4. The relevant execution/deployment actually ran with the updated digest; merely merging a workflow change is not proof of rollout.
5. For infrequent/inactive workflows, track the required update before the next execution.

**At the time of Rob's report:**

| Consumer | main reference | dev reference |
|---|---|---|
| `gen-cohort-release-nf` | `0.0.37` | `0.0.37` |
| `gen-release-candidate-qc-nf` | `0.0.34` | `0.0.34` |
| `gen-ctre-nf` | `0.0.37` | `0.0.37` |
| `gen-eurofins-qc-nf` | `0.0.34` | `0.0.34` |
| `gen-gplc-cohort-release-nf` | `0.0.37` | `0.0.37` |
| `gen-gplc-nf` | `0.0.20` (GHCR) | `0.0.20` (GHCR) |
| `gen-simulation-nf` | Not used | Not used |
| `gen-dnax-upload` | `0.0.37` (default) | `0.0.26` (default, GHCR) |

Rob identified `0.0.20` and `0.0.26` as Ubuntu 22.04-based, so Debian-specific truststore assumptions should not be applied automatically. The table reflects **references stated by Rob**, not verified current running deployments.

## 7. Completion criteria for GG-353

- [ ] New release tag, digest, and source revision recorded.
- [ ] Release image OS, OpenJDK, certificate packages, and Java truststore identified.
- [ ] Exact affected certificate fingerprints checked against the truststore (where the advisory provides them).
- [ ] Java rejects the intended affected G3 test chain using its actual default TLS configuration.
- [ ] No unreviewed custom truststores / certificate overrides in relevant workloads.
- [ ] Consumer workflow changes are merged and correctly pinned.
- [ ] Deployed or executed workloads verified to use the new image digest.
- [ ] Older/rarely executed consumers tracked appropriately before their next execution.
- [ ] GG-353 updated with findings, remaining scope, and InfoSec's disposition.

## Quick reference: what we already learned

**The image-level test passing is not the same as the production remediation being complete.** Rob's replacement image should be tested when available; application owners must separately confirm adoption across the relevant consumer workflows and executions. Until then, avoid describing GG-353 as fully remediated.
