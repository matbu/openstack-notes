import subprocess

cmd = "for i in $(heat resource-list -n 5 overcloud | grep -i failed | grep OS:: | cut -d '|' -f3 |  xargs -0); do echo $i; done;"
shell = subprocess.Popen(cmd,shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
uuids = shell.communicate()[0]
for uuid in uuids.splitlines():
    if not 'WARNING' in uuid:
        cmd = "heat deployment-show %s" % uuid
        shell = subprocess.Popen(cmd,shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        out = shell.communicate()[0]
        print out.replace('\\n', '\n')
