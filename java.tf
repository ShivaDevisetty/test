notepad "$HOME\DockerSecurityCheck\CheckTLS.java"

-------------------------------

import javax.net.ssl.*;
import java.net.URI;

public class CheckTLS {
    public static void main(String[] args) throws Exception {
        String host = "xx-g3b-xxxxxx.we-have-a-xxxx.com";

        try {
            URI uri = new URI("https://" + host);
            var connection = (HttpsURLConnection) uri.toURL().openConnection();
            connection.setConnectTimeout(10000);
            connection.setReadTimeout(10000);
            connection.connect();

            System.out.println("TLS_VERIFICATION_SUCCEEDED");
        } catch (SSLHandshakeException e) {
            System.out.println("TLS_VERIFICATION_FAILED");
            System.out.println(e.getMessage());
        }
    }
}

------

docker run --rm --network bridge --entrypoint java -v "$($HOME)\DockerSecurityCheck:/test:ro" $Image /test/CheckTLS.java




-------------------
$code = @'
import javax.net.ssl.*;
import java.net.URI;

public class CheckTLS {
    public static void main(String[] args) throws Exception {
        String host = "dv-g3b-emudhra.we-have-a-problem.com";

        try {
            URI uri = new URI("https://" + host);
            HttpsURLConnection connection =
                (HttpsURLConnection) uri.toURL().openConnection();

            connection.setConnectTimeout(10000);
            connection.setReadTimeout(10000);
            connection.connect();

            System.out.println("TLS_VERIFICATION_SUCCEEDED");

        } catch (SSLHandshakeException e) {
            System.out.println("TLS_VERIFICATION_FAILED");
            System.out.println(e.getMessage());

        } catch (Exception e) {
            System.out.println("TEST_INCONCLUSIVE");
            System.out.println(e.getClass().getName() + ": " + e.getMessage());
        }
    }
}
'@

$code | Set-Content -Path "$HOME\DockerSecurityCheck\CheckTLS.java" -Encoding UTF8

---------------------

Test-Path "$HOME\DockerSecurityCheck\CheckTLS.java"

-----

docker run --rm --network bridge --entrypoint java -v "${HOME}\DockerSecurityCheck:/test:ro" $Image /test/CheckTLS.java
