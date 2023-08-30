package org.jboss.as.quickstarts.test.openshift;

import cz.xtf.core.helm.HelmBinary;
import cz.xtf.core.helm.HelmClients;
import cz.xtf.core.openshift.OpenShifts;

import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.Stream;

public class HelmFacade {

    public static final String HELM_SET_PREFIX = "helm.set.";

    // In our setup we rely on an installed Helm repo.
    // In Intersmash, this value is rather the path of the chart checked out from Git
    // I mention this in case we need to do the same down the line. In short this is the
    // argument to 'help install' pointing to the Helm chart
    public static final String HELM_CHART_NAME = "wildfly/wildfly";

    private final HelmBinary helmBinary = HelmClients.adminBinary();

    private String helmChartLocation;
    private final String applicationName;
    private final Path helmChartValuesLocation;
    private final List<String> setOverrideArguments;

    public HelmFacade(String helmChartLocation, String applicationName, Path helmChartValuesLocation) {
        this.helmChartLocation = helmChartLocation;
        this.applicationName = applicationName;
        this.helmChartValuesLocation = helmChartValuesLocation;

        List<String> setOverrideArguments = new ArrayList<>();
        for (Object property : System.getProperties().keySet()) {
            if (property instanceof String) {
                String propName = (String) property;
                if (propName.startsWith(HELM_SET_PREFIX)) {
                    String helmSetName = propName.substring(HELM_SET_PREFIX.length());
                    setOverrideArguments.add("--set");
                    setOverrideArguments.add(helmSetName + "=" + System.getProperty(propName));
                }
            }
        }
        this.setOverrideArguments = setOverrideArguments;
    }

    void helmDeploy() {
        helmBinary.execute(getHelmChartInstallArguments());
    }

    void helmUndeploy() {
        helmBinary.execute(getHelmChartUninstallArguments());
    }


    private String[] getHelmChartInstallArguments() {
        List<String> arguments = Stream.of("install", applicationName, helmChartLocation,
                "--replace").collect(Collectors.toList());

        // Set the values file
        arguments.add("-f");
        arguments.add(helmChartValuesLocation.toString());

        // Add the value location
        arguments.addAll(setOverrideArguments);

        arguments.addAll(Arrays.asList(
                "--kubeconfig", OpenShifts.adminBinary().getOcConfigPath(),
                // since we deploy from cloned charts repository, we need to set the "--dependency-update"
                // flag to fetch any non-local dependencies that chart requires
                // in order to prevent any issues with the helm chart
                "--dependency-update"));

        // TODO temporary debug flag for verbose output
        arguments.add("--debug");

        return arguments.toArray(new String[arguments.size()]);
    }

    private String[] getHelmChartUninstallArguments() {
        return Stream.of("uninstall", applicationName, "--kubeconfig", OpenShifts.adminBinary().getOcConfigPath())
                .collect(Collectors.toList()).stream().toArray(String[]::new);

    }
}

