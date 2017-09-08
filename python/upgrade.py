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
# along with this software.  If not, see <http://www.gnu.org/licenses/>

import yum
import subprocess
import os
import pdb

import swiftclient
from keystoneclient.v2_0 import client as ksclient
from heatclient.client import Client
from heatclient.common import template_utils
from heatclient.common import utils
from novaclient.v2 import client as nova_client
from novaclient.v2 import floating_ips
from tripleoclient.v1.undercloud import UpgradeUndercloud

_os_keystone   = None
_os_tenant_id  = None
_os_network_id = None
_inc = 0


class IdentityClient():

    token = None
    endpoint = None

    def __init__(self,  service_type, **kwargs):
        endpoint_type='publicURL'
        self.kclient = ksclient.Client(**kwargs)
        self.token = self.kclient.auth_token
        self.endpoint = self.get_identity_client(service_type, endpoint_type)

    def get_identity_client(self, service_type, endpoint_type):
        return self.kclient.service_catalog.url_for(service_type=service_type, endpoint_type=endpoint_type)


class YumUtils(object):

    yb = None

    def __init__(self) :
        self.yb = yum.YumBase()

    def yum_install(self, pkg):
        """ install package with the given package """
        for (package, matched_value) in self._yum_manage(pkg) :
            if package.name == pkg :
                self.yb.install(package)
                self.yb.buildTransaction()
                self.yb.processTransaction()

    def yum_remove(self, pkg):
        """ remove package """
        for (package, matched_value) in self._yum_manage(pkg) :
            if package.name == pkg :
                self.yb.remove(package)
                self.yb.buildTransaction()
                self.yb.processTransaction()

    def yum_update(self, pkg=None):
        """ update package """
        if pkg is None:
            self.yb.update()
        else:
            for (package, matched_value) in self._yum_manage(pkg) :
                if package.name == pkg :
                    self.yb.update(package)
                    self.yb.buildTransaction()
                    self.yb.processTransaction()

    def _yum_manage(self, pkg, list='name'):
        """ manage yum packages """
        searchlist=['name']
        arg=[pkg]
        return self.yb.searchGenerator(searchlist,arg)


class ShellUtils(object):

    def __init__(self):
        pass

    def _exec_shell_cmd(self, cmd):
        """ execute shell command """
        shell = subprocess.Popen(cmd,shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT)
        return shell.communicate()[0]

    def _exec_cmd(self, cmd):
        """ exec command without shell """
        process = subprocess.Popen(cmd.split(), stdout=subprocess.PIPE)
        response = process.communicate()[0]
        return response


class Discover():

    def __init__(self):
        pass

    # Discover templates

    # Discover Services


class Upgrade():

    undercloud_upgrade_cmd = 'openstack undercloud install'
    overcloud_init_file = """
parameter_defaults:
  UpgradeInitCommand: |
    set -e
    pushd /etc/yum.repos.d/
    rm -rf delorean*
    curl -o delorean.repo -L http://buildlogs.centos.org/centos/7/cloud/x86_64/%s/delorean.repo
    curl -o delorean-deps.repo -L http://trunk.rdoproject.org/centos7-%s/delorean-deps.repo
    popd

    yum clean all
    yum install -y python-heat-agent-*
    yum install -y ansible-pacemaker

    # update ansible.cfg
    # FIXME: Workaround for bigswitch vendor pluging
    # we need to remove those package which is broken with Ocata neutron python code
    yum remove -y python-UcsSdk openstack-neutron-bigswitch-agent python-networking-bigswitch openstack-neutron-bigswitch-lldp python-networking-odl

    # Ref https://review.openstack.org/#/c/392615 disable the old hiera hook
    # FIXME - this should probably be handled via packaging?
    rm -f /usr/libexec/os-apply-config/templates/etc/puppet/hiera.yaml
    rm -f /usr/libexec/os-refresh-config/configure.d/40-hiera-datafiles
    rm -f /etc/puppet/hieradata/*.yaml
"""

    def __init__(self):
        shell = ShellUtils()

    def undercloud(self, workaround=None):
        # launch undercloud upgrade
        yum = YumUtils()
        yum.yum_update()
        return shell._exec_cmd(undercloud_upgrade_cmd)

    def undercloud_from_cli(self):
        u = UpgradeUndercloud('tripleo', '', '')
        u.take_action('')

    def set_undercloud_repo(self):
        pass

    def overcloud_init_file(self, version, repo='rdo-trunk-master-tripleo', path='/home/stack/overcloud-repo.yaml'):
        init_environment_file = overcloud_init_template % (repo, version)
        f = open(path, 'w')
        file.write(init_environment_file)

    def overcloud_upgrade(self):
        pass

class Debug():

    def __init__(self):
        pass

def main():

    #Get credentials.
    kwargs = {'username':os.environ['OS_USERNAME'],
              'password': os.environ['OS_PASSWORD'],
              'tenant_name': os.environ['OS_TENANT_NAME'],
              'auth_url': os.environ['OS_AUTH_URL']}


    conn = swiftclient.Connection(
        authurl=os.environ['OS_AUTH_URL'],
        user=os.environ['OS_USERNAME'],
        key=os.environ['OS_PASSWORD'],
        tenant_name=os.environ['OS_TENANT_NAME'],
        auth_version='2'
    )

    # Parse Arg:
    stack_name = 'overcloud'
    # Undercloud upgrade
        # use cli ?
    identity_cli = IdentityClient('orchestration', **kwargs)
    heat = Client('1', endpoint=identity_cli.endpoint, token=identity_cli.token)
    stack = heat.stacks.get(stack_name)

    client = nova_client.client.Client(api_version='2',
                             username=kwargs.get('username'),
                             password=kwargs.get('password'),
                             project_name=kwargs.get('tenant_name'),
                             auth_url=kwargs.get('auth_url'))
    client.authenticate()


    for s in client.servers.list():
        pdb.set_trace()
#        if s.name == server:
#            for f in self.client.floating_ips.list():
#                if f.instance_id == s.id:
#                    return f.ip



    # Discover env:

    # Upgrade function


if __name__ == '__main__':
    main()



# arg parse: --upgrade-undercloud // --autodiscover // --upgrade-overcloud // --inject-workaround // --




