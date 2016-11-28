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
