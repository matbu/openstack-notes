#!/bin/bash

# Workaround ironic
sudo sed -i 's/#libvirt_uri = qemu:\/\/\/system/libvirt_uri = qemu:\/\/\/session/g' /etc/ironic/ironic.conf;
sudo systemctl restart openstack-ironic-conductor.service;
# Get the newton images
curl -sf -C- https://images.rdoproject.org/master/delorean/consistent/stable/overcloud-full.tar | tar -x
curl -sf -C- https://images.rdoproject.org/master/delorean/consistent/stable/ironic-python-agent.tar | tar -x
# Upload image
source /home/stack/stackrc
openstack overcloud image upload
openstack baremetal import --json instackenv.json
openstack baremetal configure boot
openstack baremetal introspection bulk start
