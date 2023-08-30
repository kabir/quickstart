package org.jboss.as.quickstarts.test.openshift;

import cz.xtf.core.openshift.OpenShift;
import cz.xtf.core.openshift.OpenShiftWaiters;
import cz.xtf.core.openshift.OpenShifts;
import io.fabric8.kubernetes.api.model.apps.Deployment;
import io.fabric8.openshift.api.model.Route;
import org.slf4j.event.Level;

import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.jboss.as.quickstarts.test.openshift.HelmFacade.HELM_CHART_NAME;

public class OpenShiftTestManager {

    public static final String APP_KUBERNETES_IO_INSTANCE = "app.kubernetes.io/instance";
    private final boolean clean;
    private final String applicationName;
    private final Path helmChartValuesLocation;

    private volatile OpenShift openShift;
    private volatile HelmFacade helmFacade;

    private boolean attemptedDeploy;


    private OpenShiftTestManager(Builder builder) {
        this.clean = builder.clean;
        this.applicationName = builder.applicationName;
        this.helmChartValuesLocation = builder.helmChartValuesLocation;
        openShift = OpenShifts.master();
    }

    private void initialise() throws Exception {
        if (clean) {
            cleanAll();
        }

        try {

            // TODO pre-install things like DBs etc. if not included in the Helm chart

            helmFacade = new HelmFacade(HELM_CHART_NAME, applicationName, helmChartValuesLocation);
            helmFacade.helmDeploy();

            try {
                waitForPodsToBeReady();
            } catch (Exception e) {
                Thread.sleep(1000);
                waitForPodsToBeReady();
            }
        } catch (Exception e) {
            try {
                close();
            } catch (Exception ex) {
                System.err.println("Problems cleaning up after failure");
                ex.printStackTrace();
            }
            throw e;
        }
    }

    private void waitForPodsToBeReady() {
        // The WildFly Helm charts use the applicationName as the name of the deployment
        Deployment deployment = openShift.apps().deployments().withName(applicationName).get();
        int replicas = deployment.getSpec().getReplicas();
        if (replicas == 0) {
            // Hopefully this isn't too strict. If so figure out something else to wait on
            throw new IllegalStateException("We cannot wait for an application with zero replicas");
        }
        OpenShiftWaiters.get(openShift, () -> false)
                .areExactlyNPodsReady(replicas, APP_KUBERNETES_IO_INSTANCE, applicationName).level(Level.DEBUG)
                .waitFor();
    }

    public static Builder builder(Class<?> testClass, String applicationName) {
        return new Builder(testClass, applicationName);
    }


    private void cleanAll() {
        OpenShifts.master().clean().waitFor();
    }

    public void close() {
    }

    public String getApplicationRouteHost() {
        Route route = openShift.routes().withName(applicationName).get();
        String host = route.getSpec().getHost();
        return "https://" + host;
    }

    public static class Builder {
        private final Class<?> testClass;
        private final String applicationName;
        boolean clean = true;
        Path helmChartValuesLocation;

        public Builder(Class<?> testClass, String applicationName) {
            this.testClass = testClass;
            this.applicationName = applicationName;
        }

        public Builder skipClean() {
            this.clean = false;
            return this;
        }

        /**
         * Sets the location of the helm chart values file relative to the project directory;
         * @param relativePath relative location
         * @return this builder
         */
        public Builder setHelmChartValuesLocation(String relativePath) {
            try {
                URL url = testClass.getProtectionDomain().getCodeSource().getLocation();
                System.out.println(url);
                Path path = Path.of(url.toURI());
                String error = "Expected " + path + " to be in a target/test-classes child directory";
                if (!path.endsWith("test-classes")) {
                    throw new IllegalStateException(error);
                }
                path = path.getParent();
                if (!path.endsWith("target")) {
                    throw new IllegalStateException(error);
                }
                path = path.getParent();
                helmChartValuesLocation = path.resolve(relativePath);
                if (!Files.exists(helmChartValuesLocation)) {
                    throw new IllegalStateException("Determined helm values location does not exist: " + helmChartValuesLocation);
                }
                return this;
            } catch (Error | RuntimeException e) {
                throw e;
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        }

        public OpenShiftTestManager buildAndInitialise() throws Exception {
            if (helmChartValuesLocation == null) {
                throw new IllegalStateException("helmChartValuesLocation not set");
            }
            OpenShiftTestProperties.propagateProperties();
            OpenShiftTestManager manager = new OpenShiftTestManager(this);
            manager.initialise();
            return manager;
        }
    }
}
