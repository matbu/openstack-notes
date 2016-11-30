#!/bin/bash
source /home/stack/stackrc;
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

cat <<EOF>> repo.yaml
parameter_defaults:
  UpgradeInitCommand: |
    set -e
    curl -o /etc/yum.repos.d/delorean.repo http://buildlogs.centos.org/centos/7/cloud/x86_64/rdo-trunk-master-tested/delorean.repo
    curl -o /etc/yum.repos.d/delorean-deps.repo http://trunk.rdoproject.org/centos7-master/delorean-deps.repo
    yum clean all
EOF

cat <<EOF>> custom.yaml
parameter_defaults:
  KeystoneFernetKey1: azerty
  KeystoneFernetKey0: azerty
EOF

echo "Json to Yaml:"
#i = {}
#print yaml.dump(yaml.load(json.dumps(json.loads(i))), default_flow_style=False)


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

git clone https://github.com/openstack/tripleo-heat-templates.git /home/stack/tripleo-heat-templates
for i in 393448; do # already merged 375973 375977
    curl "https://review.openstack.org/changes/$i/revisions/current/patch" |base64 --decode > /home/stack/"$i.patch"
    pushd tripleo-heat-templates
    patch -N -p1 -b -z .first < /home/stack/$i.patch
    popd
done

for i in 403397; do # already merged 375973 375977
    curl "https://review.openstack.org/changes/$i/revisions/current/patch" |base64 --decode > /home/stack/"$i.patch"
    pushd tripleo-heat-templates
    patch -N -p1 -b -z .first < /home/stack/$i.patch
    popd
done

echo "Create default ansible module dir"
run-on-overcloud 'sudo mkdir -p /usr/share/my_modules/'
echo "Set ansible module dir"
run-on-overcloud 'sudo sed -i "\$alibrary = /usr/share/my_modules/" /etc/ansible/ansible.cfg'
echo "Set rights"
run-on-overcloud 'sudo chown -R heat-admin:heat-admin /usr/share/my_modules/'
for i in $(nova list|grep ctlplane|awk -F' ' '{ print $12 }'|awk -F'=' '{ print $2 }'); do
        scp -o StrictHostKeyChecking=no /home/stack/tripleo-heat-templates/ansible/library/* heat-admin@$i:/usr/share/my_modules/
done

echo "deploy command w/o net iso and HA:"
echo "  openstack overcloud deploy --templates tripleo-heat-templates     -e tripleo-heat-templates/overcloud-resource-registry-puppet.yaml     -e tripleo-heat-templates/environments/major-upgrade-composable-steps.yaml --no-cleanup -e custom.yaml -e repo.yaml   "

echo "deploy command with pacemaker and network isolation:"
echo "  openstack overcloud deploy --templates tripleo-heat-templates     -e tripleo-heat-templates/overcloud-resource-registry-puppet.yaml \
    -e tripleo-heat-templates/environments/network-isolation.yaml \
    -e tripleo-heat-templates/environments/net-single-nic-with-vlans.yaml \
    -e ~/network-environment.yaml \
    -e tripleo-heat-templates/environments/puppet-pacemaker.yaml \
    -e tripleo-heat-templates/environments/major-upgrade-composable-steps.yaml --no-cleanup -e custom.yaml -e repo.yaml  "
