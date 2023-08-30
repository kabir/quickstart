package org.jboss.as.quickstarts.test.openshift;

public class OpenShiftTestProperties {
    public static final String OPENSHIFT_DEPLOY = "openshift.deploy";
    public static final String HELM_DEPLOY_TIMEOUT = "openshift.helm.deploy.timeout";
    public static final String OPENSHIFT_TOKEN = "openshift.token";
    public static final String OPENSHIFT_NAMESPACE = "openshift.namespace";
    public static final String OPENSHIFT_API_URL = "openshift.api.url";

    static void propagateProperties() {
        setXtfProperty(HELM_DEPLOY_TIMEOUT, "xtf.waiting.timeout", "600000");
        setXtfProperty(OPENSHIFT_TOKEN, "xtf.openshift.admin.token", null);
        setXtfProperty(OPENSHIFT_TOKEN, "xtf.openshift.master.token", null);
        setXtfProperty(OPENSHIFT_NAMESPACE, "xtf.openshift.namespace", null);
        setXtfProperty(OPENSHIFT_NAMESPACE, "xtf.bm.namespace", null);
        setXtfProperty(OPENSHIFT_API_URL, "xtf.openshift.url", null);
        System.setProperty("xtf.openshift.skip.filter.classes", "DedicatedAdminCleanerFilter");
        System.setProperty("xtf.openshift.skip.clean.labels", "toolchain.dev.openshift.com/provider:codeready-toolchain,app.kubernetes.io/instance:modelmesh-controller");
    }

    private static void setXtfProperty(String qsProperty, String xtfProperty, String defaultValue) {
        setXtfProperty(qsProperty, xtfProperty, defaultValue, false);
    }

    private static void setXtfProperty(String qsProperty, String xtfProperty, String defaultValue, boolean nullable) {
        String value = System.getProperty(qsProperty, defaultValue);
        if (value == null && !nullable) {
            throw new IllegalStateException("No value was set for " + qsProperty);
        }
        System.setProperty(xtfProperty, value);
    }
}
