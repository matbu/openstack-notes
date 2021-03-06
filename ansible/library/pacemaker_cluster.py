#!/usr/bin/python
#coding: utf-8 -*-

# (c) 2016, Mathieu Bultel <mbultel@redhat.com>
#
# This module is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this software.  If not, see <http://www.gnu.org/licenses/>.

import time
from distutils.version import StrictVersion

DOCUMENTATION = '''
---
module: pacemaker_manage
short_description: Manage a pacemaker cluster
extends_documentation_fragment: openstack
version_added: "2.2"
author: "Mathieu Bultel (matbu)"
description:
   - Manage a pacemaker cluster and nodes from Ansible
options:
    state:
      description:
        - Indicate desired state of the cluster
      choices: ['online', 'offline', 'restart', 'cleanup']
      required: true
    node:
      description:
        - Specify which node of the cluster you want to manage. None == the
          cluster status itself, 'all' == check the status of all nodes.
      required: false
      default: None
    timeout:
      description:
        - Timeout when the module should considered that the action has failed
      required: false
      default: 300
    force:
      description:
        - Force the change of the cluster state
      required: false
      default: true
requirements:
    - "python >= 2.6"
    - "shade"
'''
EXAMPLES = '''
---
- name: Set cluster Online
  hosts: localhost
  gather_facts: no
  tasks:
    - name: get cluster state
      pacemaker_cluster: state=online
'''

RETURN = '''
change:
    description: True if the cluster state has changed
    type: bool
out:
    description: The output of the current state of the cluster. It return a
                 list of the nodes state.
    type: string
    sample: "out": [["  overcloud-controller-0", " Online"]]}
rc:
    description: exit code of the module
    type: bool
'''

_PCS_CLUSTER_DOWN="Error: cluster is not currently running on this node"

def get_cluster_status(module):
    cmd = "pcs cluster status"
    rc, out, err = module.run_command(cmd)
    if out in _PCS_CLUSTER_DOWN:
        return 'offline'
    else:
        return 'online'

def get_node_status(module, node='all'):
    if node == 'all':
        cmd = "pcs cluster pcsd-status %s" % node
    else:
        cmd = "pcs cluster pcsd-status"
    rc, out, err = module.run_command(cmd)
    if rc is 1:
        module.fail_json(msg="Command execution failed.\nCommand: `%s`\nError: %s" % (cmd, err))
    status = []
    for o in out.splitlines():
        status.append(o.split(':'))
    return status

def clean_cluster(module, timeout):
    cmd = "pcs resource cleanup"
    rc, out, err = module.run_command(cmd)
    if rc is 1:
        module.fail_json(msg="Command execution failed.\nCommand: `%s`\nError: %s" % (cmd, err))

def set_cluster(module, state, timeout, force):
    if state == 'online':
        cmd = "pcs cluster start"
    if state == 'offline':
        cmd = "pcs cluster stop"
        if force:
            cmd = "%s --force" % cmd
    rc, out, err = module.run_command(cmd)
    if rc is 1:
        module.fail_json(msg="Command execution failed.\nCommand: `%s`\nError: %s" % (cmd, err))

    t = time.time()
    ready = False
    while time.time() < t+timeout:
        cluster_state = get_cluster_status(module)
        if cluster_state == state:
            ready = True
            break
    if not ready:
        module.fail_json(msg="Failed to set the state `%s` on the cluster\n" % (state))

def set_node(module, state, timeout, force, node='all'):
    # map states
    if state == 'online':
        cmd = "pcs cluster start"
    if state == 'offline':
        cmd = "pcs cluster stop"
        if force:
            cmd = "%s --force" % cmd

    nodes_state = get_node_status(module, node)
    for node in nodes_state:
        if node[1].strip().lower() != state:
            cmd = "%s %s" % (cmd, node[0].strip())
            rc, out, err = module.run_command(cmd)
            if rc is 1:
                module.fail_json(msg="Command execution failed.\nCommand: `%s`\nError: %s" % (cmd, err))

    t = time.time()
    ready = False
    while time.time() < t+timeout:
        nodes_state = get_node_status(module)
        for node in nodes_state:
            if node[1].strip().lower() == state:
                ready = True
                break
    if not ready:
        module.fail_json(msg="Failed to set the state `%s` on the cluster\n" % (state))

def main():
    argument_spec = dict(
        state = dict(choices=['online', 'offline', 'restart', 'cleanup']),
        node  = dict(default=None),
        timeout=dict(default=300, type='int'),
        force=dict(default=True, type='bool'),
    )

    module = AnsibleModule(argument_spec,
        supports_check_mode=True,
    )
    changed = False
    state = module.params['state']
    node = module.params['node']
    force = module.params['force']
    timeout = module.params['timeout']

    if state in ['online', 'offline']:
        # Get cluster status
        if node is None:
            cluster_state = get_cluster_status(module)
            if cluster_state == state:
                module.exit_json(changed=changed,
                         out=cluster_state)
            else:
                set_cluster(module, state, timeout, force)
                cluster_state = get_cluster_status(module)
                if cluster_state == state:
                    module.exit_json(changed=True,
                         out=cluster_state)
                else:
                    module.fail_json(msg="Fail to bring the cluster %s" % state)
        else:
            cluster_state = get_node_status(module, node)
            # Check cluster state
            for node_state in cluster_state:
                if node_state[1].strip().lower() == state:
                    module.exit_json(changed=changed,
                             out=cluster_state)
                else:
                    # Set cluster status if needed
                    set_cluster(module, state, timeout, force)
                    cluster_state = get_node_status(module, node)
                    module.exit_json(changed=True,
                             out=cluster_state)

    if state in ['restart']:
        set_cluster(module, 'offline', timeout, force)
        cluster_state = get_cluster_status(module)
        if cluster_state == 'offline':
            set_cluster(module, 'online', timeout, force)
            cluster_state = get_cluster_status(module)
            if cluster_state == 'online':
                module.exit_json(changed=True,
                     out=cluster_state)
            else:
                module.fail_json(msg="Failed during the restart of the cluster, the cluster can't be started")
        else:
            module.fail_json(msg="Failed during the restart of the cluster, the cluster can't be stopped")

    if state in ['cleanup']:
        set_cluster(module, state, timeout, force)
        module.exit_json(changed=True,
                 out=cluster_state)

from ansible.module_utils.basic import *
if __name__ == '__main__':
    main()
