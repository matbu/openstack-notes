#!/bin/bash

export VIRTHOST=$1
export WORKSPACE=$2

if [ -d 'tripleo-quickstart' ]; then
    git clone https://git.openstack.org/openstack/tripleo-quickstart
fi
pushd tripleo-quickstart
bash quickstart.sh \
    --config $WORKSPACE/config/general_config/$CONFIG.yml \
    --working-dir $WORKSPACE/ \
    --no-clone \
    --bootstrap \
    --tags "teardown-all,untagged,provision,environment,undercloud-scripts,undercloud-install"\
    --teardown all \
    --requirements quickstart-extras-requirements.txt \
    --playbook quickstart-extras.yml \
    --release ${CI_ENV:+$CI_ENV/}$RELEASE${REL_TYPE:+-$REL_TYPE} \
    $VIRTHOST
popd

#ansible-playbook -vvvv upgrade-play.yaml -i hosts
