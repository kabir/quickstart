package org.jboss.as.quickstarts.test.openshift;

import cz.xtf.core.openshift.OpenShifts;
import org.jboss.intersmash.tools.IntersmashConfig;
import org.jboss.intersmash.tools.provision.helm.WildflyHelmChartOpenShiftProvisioner;

import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;

public class OpenShiftTestManager {
    private final boolean clean;
    private final Path helmChartValuesLocation;

    private WildflyHelmChartOpenShiftProvisioner provisioner;
    private boolean attemptedPredeploy;
    private boolean attemptedDeploy;


    private OpenShiftTestManager(Builder builder) {
        this.clean = builder.clean;
        this.helmChartValuesLocation = builder.helmChartValuesLocation;
    }

    private void initialise() throws Exception {
        if (clean) {
            cleanAll();
        }

        try {
            final WildflyHelmChartApplicaton application = new WildflyHelmChartApplicaton(helmChartValuesLocation);
            if (IntersmashConfig.deploymentsRepositoryUrl() != null) {
                application.addSetOverride("build.uri", IntersmashConfig.deploymentsRepositoryUrl());
            }
            if (IntersmashConfig.deploymentsRepositoryRef() != null) {
                application.addSetOverride("build.ref", IntersmashConfig.deploymentsRepositoryRef());
            }
            if (application.getBuilderImage() != null) {
                application.addSetOverride("deploy.builderImage", application.getBuilderImage());
            }
            if (application.getRuntimeImage() != null) {
                application.addSetOverride("deploy.runtimeImage", application.getRuntimeImage());
            }

            // and now get an EAP 8/WildFly provisioner for that application
            WildflyHelmChartOpenShiftProvisioner provisioner = new WildflyHelmChartOpenShiftProvisioner(application);
            // deploy
            attemptedPredeploy = true;
            provisioner.preDeploy();

            attemptedDeploy = true;
            provisioner.deploy();
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
    public static Builder builder(Class<?> testClass) {
        return new Builder(testClass);
    }


    private void cleanAll() {
        OpenShifts.master().clean().waitFor();
    }

    public void close() {
        if (attemptedDeploy) {
            provisioner.undeploy();
        }
        if (attemptedPredeploy) {
            provisioner.postUndeploy();
        }
    }

    public static class Builder {
        private final Class<?> testClass;
        boolean clean = true;
        Path helmChartValuesLocation;

        public Builder(Class<?> testClass) {
            this.testClass = testClass;
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

            OpenShiftTestManager manager = new OpenShiftTestManager(this);
            manager.initialise();
            return manager;
        }
    }


}
