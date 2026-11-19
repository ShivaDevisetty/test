@'
import javax.net.ssl.*;
import java.net.URL;

class CheckTLS {
    public static void main(String[] args) throws Exception {
        String host = "dv-g3b-emudhra.we-have-a-problem.com";
        try {
            HttpsURLConnection conn =
                (HttpsURLConnection) new URL("https://" + host).openConnection();
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(10000);
            conn.connect();
            System.out.println("TLS_ACCEPTED");
        } catch (SSLHandshakeException e) {
            System.out.println("TLS_REJECTED: " + e.getMessage());
        } catch (Exception e) {
            System.out.println("TEST_INCONCLUSIVE: " + e);
        }
    }
}
'@ | Set-Content "$HOME\DockerSecurityCheck\CheckTLS.java"

-----------------------

Test-Path "$HOME\DockerSecurityCheck\CheckTLS.java"

--------------------

$Image = "ourfuturehealth.azurecr.io/ourfuturehealth/gen-pipeline-runner-nf/pipeline_runner:0.0.39-a4"

-------------------

docker run --rm --network bridge --entrypoint java -v "${HOME}\DockerSecurityCheck:/test:ro" $Image /test/CheckTLS.java
