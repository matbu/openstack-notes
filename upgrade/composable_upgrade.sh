#!/bin/bash
source /home/stack/stackrc;
echo "########################################################"
# run command on overcloud
function run-on-overcloud() {
    for i in $(nova list|grep ctlplane|awk -F' ' '{ print $12 }'|awk -F'=' '{ print $2 }'); do
        ssh -o StrictHostKeyChecking=no heat-admin@$i "$@"
    done
}
echo "Clone heat-templates current master to install heat ansible hook"
run-on-overcloud 'sudo git clone https://git.openstack.org/openstack/heat-templates.git /root/heat-templates;'
echo "install ansible hook"
run-on-overcloud 'sudo /root/heat-templates/hot/software-config/elements/heat-config-ansible/install.d/50-heat-config-hook-ansible'

echo "########################################################"
echo " cat init repo"
cat <<EOF>> init-repo.yaml
parameter_defaults:
  UpgradeInitCommand: |
    set -e
    curl -L -o /etc/yum.repos.d/delorean.repo https://trunk.rdoproject.org/centos7-master/current-tripleo/delorean.repo
    curl -L -o /etc/yum.repos.d/delorean-deps.repo http://trunk.rdoproject.org/centos7-ocata/delorean-deps.repo
    yum clean all
    yum install -y python-heat-agent-*
    yum install -y ansible-pacemaker
    yum remove -y python-UcsSdk openstack-neutron-bigswitch-agent python-networking-bigswitch openstack-neutron-bigswitch-lldp python-networking-odl
    crudini --set /etc/ansible/ansible.cfg DEFAULT library /usr/share/ansible-modules/
    rm -f /usr/libexec/os-apply-config/templates/etc/puppet/hiera.yaml
    rm -f /usr/libexec/os-refresh-config/configure.d/40-hiera-datafiles
    rm -f /etc/puppet/hieradata/*.yaml
EOF

echo "########################################################"
cat <<EOF>> custom.yaml
parameter_defaults:
  KeystoneFernetKey1: azerty
  KeystoneFernetKey0: azerty
EOF

echo "########################################################"
echo "test jinja2 templating"
cat <<EOF>> render.py
from jinja2 import Environment, FileSystemLoader
#env = Environment(loader=FileSystemLoader('templates'))
 
HTML = open('up.j2', 'rb')
import pdb
print Environment().from_string(HTML.read()).render(roles=['controller'])
EOF

echo "########################################################"
echo "Json to Yaml:"
cat <<EOF>> json2yaml.py
import sys, json, yaml

if len(sys.argv) == 2:
    # open input file
    f = open(sys.argv[1], 'rb')
    # create the rendering yaml file
    yamlfile = open('rendered.yaml', 'w')
    # dump yaml
    yamlfile.write(yaml.dump(yaml.load(json.dumps(json.loads(f.read()))), default_flow_style=False))
else:
    print "You must provide a json file"
    sys.exit()
EOF

echo "########################################################"
openstack stack output show overcloud EnabledServices
# usefull review:
# a
# https://review.openstack.org/#/c/403397/13 (with workaround)
# https://review.openstack.org/#/c/403397 pacemaker (without workaround)
# https://review.openstack.org/#/c/408631 step0

# https://review.openstack.org/418920 neutron

echo "########################################################"
for i in $(grep -r 'heat_template_version: ocata' tripleo-heat-templates/* | cut -d ':' -f1 |  xargs -0); do sed -i "s/heat_template_version: ocata/heat_template_version: newton/" $i; done;
echo "########################################################"
for i in $(grep -r 'step0,validation' tripleo-heat-templates/* | cut -d ':' -f1 |  xargs -0); do sed -i "s/step0,validation/validation/" $i; done;
echo "########################################################"
crudini --set nova.conf DEFAULT metadata_workers 1

echo "########################################################"
echo "grab review"
git clone https://github.com/openstack/tripleo-heat-templates.git /home/stack/tripleo-heat-templates
for i in 393448; do # already merged 375973 375977
    curl "https://review.openstack.org/changes/$i/revisions/15/patch" |base64 --decode > /home/stack/"$i.patch"
    pushd tripleo-heat-templates
    patch -N -p1 -b -z .first < /home/stack/$i.patch
    popd
done

#pacemaker
for i in 403397; do # already merged 375973 375977
    curl "https://review.openstack.org/changes/$i/revisions/current/patch" |base64 --decode > /home/stack/"$i.patch"
    pushd tripleo-heat-templates
    patch -N -p1 -b -z .first < /home/stack/$i.patch
    popd
done

for i in 408631; do # already merged 375973 375977
    curl "https://review.openstack.org/changes/$i/revisions/current/patch" |base64 --decode > /home/stack/"$i.patch"
    pushd tripleo-heat-templates
    patch -N -p1 -b -z .first < /home/stack/$i.patch
    popd
done

#neutron
for i in 418920; do # already merged 375973 375977
    curl "https://review.openstack.org/changes/$i/revisions/current/patch" |base64 --decode > /home/stack/"$i.patch"
    pushd tripleo-heat-templates
    patch -N -p1 -b -z .first < /home/stack/$i.patch
    popd
done

#nova
for i in 405241; do # already merged 375973 375977
    curl "https://review.openstack.org/changes/$i/revisions/current/patch" |base64 --decode > /home/stack/"$i.patch"
    pushd tripleo-heat-templates
    patch -N -p1 -b -z .first < /home/stack/$i.patch
    popd
done

echo "########################################################"
echo "Create default ansible module dir"
run-on-overcloud 'sudo mkdir -p /usr/share/my_modules/'
echo "Set ansible module dir"
run-on-overcloud 'sudo sed -i "\$alibrary = /usr/share/my_modules/" /etc/ansible/ansible.cfg'
echo "Set rights"
run-on-overcloud 'sudo chown -R heat-admin:heat-admin /usr/share/my_modules/'
for i in $(nova list|grep ctlplane|awk -F' ' '{ print $12 }'|awk -F'=' '{ print $2 }'); do
        scp -o StrictHostKeyChecking=no /home/stack/tripleo-heat-templates/ansible/library/* heat-admin@$i:/usr/share/my_modules/
done

echo "########################################################"
echo "deploy command w/o net iso and HA:"
echo "  openstack overcloud deploy --templates tripleo-heat-templates     -e tripleo-heat-templates/overcloud-resource-registry-puppet.yaml     -e tripleo-heat-templates/environments/major-upgrade-composable-steps.yaml --no-cleanup -e custom.yaml -e repo.yaml   "

echo "########################################################"
echo "deploy command with pacemaker and network isolation:"
echo "  openstack overcloud deploy --templates tripleo-heat-templates     -e tripleo-heat-templates/overcloud-resource-registry-puppet.yaml \
    -e tripleo-heat-templates/environments/network-isolation.yaml \
    -e tripleo-heat-templates/environments/net-single-nic-with-vlans.yaml \
    -e ~/network-environment.yaml \
    -e tripleo-heat-templates/environments/puppet-pacemaker.yaml \
    -e tripleo-heat-templates/environments/major-upgrade-composable-steps.yaml --no-cleanup -e custom.yaml -e repo.yaml  "

echo "########################################################"
echo "  openstack overcloud deploy  -e /usr/share/openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml -e /home/stack/overcloud_services.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/major-upgrade-all-in-one.yaml -e /home/stack/init-repo.yaml --templates /usr/share/openstack-tripleo-heat-templates   "

echo "########################################################"
echo " deploy command PCS no converge"
echo "
openstack overcloud deploy --templates tripleo-heat-templates-ocata \
    -e tripleo-heat-templates-ocata/environments/network-isolation.yaml \
    -e tripleo-heat-templates-ocata/environments/net-single-nic-with-vlans.yaml \
    -e ~/network-environment.yaml \
    -e tripleo-heat-templates-ocata/environments/puppet-pacemaker.yaml \
    -e tripleo-heat-templates-ocata/environments/major-upgrade-composable-steps.yaml --no-cleanup -e init-repo.yaml
"

echo "########################################################"
echo " All in one PCS"
echo "
openstack overcloud deploy --templates tripleo-heat-templates \
    -e tripleo-heat-templates/environments/network-isolation.yaml \
    -e tripleo-heat-templates/environments/net-single-nic-with-vlans.yaml \
    -e ~/network-environment.yaml \
    -e tripleo-heat-templates/environments/puppet-pacemaker.yaml \
    -e tripleo-heat-templates/environments/major-upgrade-all-in-one.yaml \
     --no-cleanup -e init-repo.yaml
"







openstack overcloud deploy --templates /usr/share/openstack-tripleo-heat-templates \
    -e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/net-single-nic-with-vlans.yaml \
    -e ~/network-environment.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/puppet-pacemaker.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/major-upgrade-composable-steps.yaml --no-cleanup -e init-repo.yaml
