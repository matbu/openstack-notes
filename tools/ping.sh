#!/bin/bash
# ping test
# create key
nova keypair-add --pub-key ~/.ssh/id_rsa.pub default
# get cirros image
wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
# upload to glance
glance image-create --name="cirros" --disk-format=qcow2 \
  --container-format=bare  < cirros-0.3.4-x86_64-disk.img
# create external net
neutron net-create nova --router:external --provider:network_type vlan \
  --provider:physical_network datacentre --provider:segmentation_id 10
# create external subnet
neutron subnet-create --name nova --disable-dhcp \
          --allocation-pool start=10.0.0.40,end=10.0.0.240 \
          --gateway=10.0.0.1 nova 10.0.0.1/24
# create tenant net
neutron net-create private
# create tenant subnet
neutron subnet-create --name private --disable-dhcp \
  --allocation-pool start=10.0.1.2,end=10.0.1.100 \
  --gateway 10.0.1.1  private 10.0.1.0/24
# create router
neutron router-create router1
# add gateway to router1
neutron router-gateway-set router1 nova
# add interface to router1
TENANT_SUBNET=$(neutron net-list | grep private | awk '{ print $6 }')
neutron router-interface-add router1 $TENANT_SUBNET
# autorize ping and ssh
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0;
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
# boot cirros instance
IMG=$(glance image-list | grep cirros | awk '{ print $2 }')
NET=$(neutron net-list | grep private | awk '{ print $2 }')
nova boot --flavor m1.small --image $IMG --nic net-id=$NET --security-group default --key-name default test
