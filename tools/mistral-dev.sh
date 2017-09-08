#!/bin/bash

git clone https://github.com/openstack/python-tripleoclient.git
git clone https://git.openstack.org/openstack/tripleo-common

cat <<EOF>> patch-cli.sh
for i in \$1; do
    curl "https://review.openstack.org/changes/\$i/revisions/current/patch" |base64 --decode > /home/stack/"\$i.patch"
    cd ~/python-tripleoclient; patch -N -p1 -b -z .first < /home/stack/\$i.patch
done
EOF

chmod +x patch-cli.sh

cat <<EOF>> patch-common.sh
for i in \$1; do
    curl "https://review.openstack.org/changes/\$i/revisions/current/patch" |base64 --decode > /home/stack/"\$i.patch"
    cd ~/tripleo-common; patch -N -p1 -b -z .first < /home/stack/\$i.patch
done
EOF

chmod +x patch-common.sh

cat <<EOF>> mistral.sh
pushd ~/tripleo-common
sudo rm -Rf /usr/lib/python2.7/site-packages/tripleo_common*
sudo python setup.py install
sudo cp /usr/share/tripleo-common/sudoers /etc/sudoers.d/tripleo-common
sudo systemctl restart openstack-mistral-executor
sudo systemctl restart openstack-mistral-engine
# this loads the actions via entrypoints
sudo mistral-db-manage populate
# make sure the new actions got loaded
mistral action-list | grep tripleo
popd
EOF

chmod +x mistral.sh

# patch:
# https://review.openstack.org/#/c/463765/ tripleo-common
./patch-common.sh 487496
#463765

# https://review.openstack.org/#/c/463728/ tripleoclient
./patch-cli.sh 487488
#463728

sudo yum remove -y python-tripleoclient

pushd python-tripleoclient
sudo python setup.py install
popd

./mistral.sh
# Create or update the workbook:
#mistral workbook-update /usr/share/openstack-tripleo-common/workbooks/major_upgrade.yaml
mistral workbook-update /usr/share/openstack-tripleo-common/workbooks/package_update.yaml

