#!/bin/bash
if [ -d /tmp/tht ]; then
  rm -rf /tmp/tht
fi

mkdir -p /tmp/tht
pushd /tmp/tht
swift download overcloud
popd
