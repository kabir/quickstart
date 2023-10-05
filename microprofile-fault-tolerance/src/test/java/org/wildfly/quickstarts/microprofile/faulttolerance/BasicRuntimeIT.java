package org.wildfly.quickstarts.microprofile.faulttolerance;

import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClientBuilder;
import org.junit.Test;

import java.io.IOException;
import java.net.URISyntaxException;

import static org.junit.Assert.assertEquals;
import static org.wildfly.quickstarts.microprofile.faulttolerance.TestUtils.getServerHost;

public class BasicRuntimeIT {

    private final CloseableHttpClient httpClient = HttpClientBuilder.create().build();
    @Test
    public void testHTTPEndpointIsAvailable() throws IOException, InterruptedException, URISyntaxException {
        HttpGet httpGet = new HttpGet(getServerHost());
        CloseableHttpResponse httpResponse = httpClient.execute(httpGet);

        assertEquals("Successful call", 200, httpResponse.getStatusLine().getStatusCode());

        httpResponse.close();

    }
}
