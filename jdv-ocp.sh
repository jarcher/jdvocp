# You may or may not need to use 'sudo' depending on which platform you 
# are using. The following is verified for Fedora (RHEL).

# Start the local OSE 
# sudo oc cluster up --image=registry.access.redhat.com/openshift3/ose --version="v3.6.173.0.5-4" 

# Use what is out there on Github, if the files don't exist locally wget them 
# by uncommenting the following commands 

export PATH=$PATH:/etc/alternatives/java_sdk/bin

rm *.json
wget https://raw.githubusercontent.com/jboss-openshift/application-templates/master/jboss-image-streams.json
wget https://raw.githubusercontent.com/jboss-openshift/application-templates/master/datavirt/datavirt63-secure-s2i.json
wget https://raw.githubusercontent.com/jboss-openshift/application-templates/master/datavirt/datavirt63-basic-s2i.json
wget https://raw.githubusercontent.com/jboss-openshift/application-templates/master/datavirt/datavirt63-extensions-support-s2i.json

sed -i 's/jboss-datagrid65-client-openshift:1.0/jboss-datagrid65-client-openshift:latest/g' datavirt63-secure-s2i.json
sed -i 's/jboss-datagrid65-client-openshift:1.0/jboss-datagrid65-client-openshift:latest/g' datavirt63-basic-s2i.json
sed -i 's/jboss-datagrid65-client-openshift:1.0/jboss-datagrid65-client-openshift:latest/g' datavirt63-extensions-support-s2i.json

sudo oc create -n openshift -f jboss-image-streams.json
sudo oc create -n openshift -f datavirt63-secure-s2i.json
sudo oc create -n openshift -f datavirt63-basic-s2i.json
sudo oc create -n openshift -f datavirt63-extensions-support-s2i.json

# The above should create 'myproject' automatically by default if not use the following command:
sudo oc login -u developer
sudo oc new-project --display-name='My Project' myproject
sudo oc login -u system:admin
sudo oc project myproject

# Create necessary sa (service account) and give the sa view access
sudo oc create serviceaccount datavirt-service-account
sudo oc policy add-role-to-user view system:serviceaccount:myproject:datavirt-service-account

# Download the 'datasources.env' from here 
# https://raw.githubusercontent.com/jboss-openshift/openshift-quickstarts/master/datavirt/dynamicvdb-datafederation/datasources.env
sudo oc secrets new datavirt-app-config datasources.env
sudo oc secrets link datavirt-service-account datavirt-app-config

export DNAME='CN=developer,O=RedHat,C=US'
export KEYPASS=mykeystorepass
export CLUSTERPASS=password
rm -f *.jks *.jceks 
keytool -genkeypair -alias jboss -storetype JKS -storepass $KEYPASS -keypass $KEYPASS -dname $DNAME -keystore keystore.jks
keytool -genseckey -alias secret-key -storetype JCEKS -storepass $CLUSTERPASS -keypass $CLUSTERPASS -keystore jgroups.jceks
sudo oc secret new datavirt-app-secret keystore.jks jgroups.jceks
sudo oc secrets link datavirt-service-account datavirt-app-secret datavirt-app-config

# For client applications
keytool -export -alias jboss -file jdv-server.crt -keystore keystore.jks -storepass $KEYPASS
keytool -import -noprompt -trustcacerts -alias jboss -file jdv-server.crt -keystore truststore.jks -storepass $KEYPASS

# For Java client applications use the following system properties
# -Djavax.net.ssl.trustStore=<path-to>/truststore.jks -Djavax.net.ssl.trustStorePassword=mykeystorepass

# Create a new app in the project 
sudo oc new-app --template=datavirt63-secure-s2i -e TEIID_USERNAME=teiidUser -e TEIID_PASSWORD=redhat1! -n myproject

# Once everything is in place try the URL of the form (yours will be different) below
#http://datavirt-app-myproject.192.168.86.35.xip.io/odata/Hibernate_Portfolio.1/ACCOUNT
