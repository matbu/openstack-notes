#!/bin/bash

# Workaround ironic
sudo sed -i 's/#libvirt_uri = qemu:\/\/\/system/libvirt_uri = qemu:\/\/\/session/g' /etc/ironic/ironic.conf;
sudo systemctl restart openstack-ironic-conductor.service;
# Get the newton images
# Get the newton images
rm -rf overcloud-full*
rm -rf ironic-python-agent.*
curl -sf -C- https://images.rdoproject.org/newton/delorean/consistent/stable/overcloud-full.tar | tar -x
curl -sf -C- https://images.rdoproject.org/newton/delorean/consistent/stable/ironic-python-agent.tar | tar -x
# Upload image
source /home/stack/stackrc
openstack overcloud image upload --update-existing
openstack baremetal import --json instackenv.json
openstack baremetal configure boot
openstack baremetal introspection bulk start
# Get the newton tripleo-heat-templates
if [ -d tripleo-heat-templates ]; then
    rm -rf tripleo-heat-templates
fi
git clone https://github.com/openstack/tripleo-heat-templates -b stable/newton
