from jinja2 import Environment, FileSystemLoader
import pdb

HTML = open('up.j2', 'rb')
print Environment().from_string(HTML.read()).render(roles=['controller'])
