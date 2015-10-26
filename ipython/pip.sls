

pip2:
  pkg.installed:
    - name: python-pip

{%- set pip_cachedir="/var/cache/pip" %}
pip-cachedir-system:
  file.directory:
    - name: {{ pip_cachedir }}
    - dir_mode: 0755
    #- owner: root
    #- group: root  # pip?
    ##- file_mode: 0644
    ##- recurse: True

