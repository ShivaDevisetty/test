Hi Team,

I've completed the independent Docker image-level verification for **GG-353 – OpenJDK/eMudhra Certificate Vulnerability** in the `gen-pipeline-runner-nf` repository.

**Image verified:** `pipeline_runner:0.0.39-a4`

**Findings:**
- Successfully pulled the image from Azure Container Registry.
- Confirmed Debian 13 and OpenJDK 21.0.13.
- Verified that Java's default truststore is linked to Debian's system-managed `/etc/ssl/certs/java/cacerts`.
- Confirmed the `ca-certificates` and `ca-certificates-java` packages are installed.
- Found no matching `emSign G3` or `AAA Certificate Services` entries in the default Java truststore.
- Confirmed that other legitimate emSign certificates (C1, C3 and G1) remain present.
- Executed a Java HTTPS certificate-validation test against the G3 test endpoint referenced in GG-353.
- Java rejected the certificate chain with `SSLHandshakeException` and `PKIX path building failed`.
- Found no additional JKS/P12/PFX truststore files in the directories searched, and no matching Java truststore overrides in the image environment or repository configuration.

**Conclusion:**
The results support Rob's assessment that the affected G3 certificate chain is not trusted by the default Java configuration in the tested image.

**Outstanding verification:**
I couldn't identify the active Azure Container Apps deployment using my current Azure access. We still need to confirm which workload uses this image and whether deployment-time configuration overrides its truststore.

Could someone please confirm the affected deployment environment, resource group, application/job name and deployed image tag or digest?

Once confirmed, we can complete the final validation and update GG-353 accordingly.
