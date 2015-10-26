
# System supervisord 
#

# Adapted from:
# - https://raw.githubusercontent.com/saltstack-formulas/graphite-formula/master/graphite/supervisor.sls

supervisor:
  pip.installed: []
  #pkg.installed: []

/etc/supervisord.conf:
  file.managed:
    - source: salt://ipython-formula/files/supervisord.conf
    ##[include]\nfiles = /etc/supervisor/conf.d/*
    - mode: 0544
    - owner: root
    - group: root

/etc/init.d/supervisor:
  file.managed:
    - source: salt://ipython/files/supervisord.init.sh
    - mode: 0544
    - owner: root
    - group: root

/var/log/supervisor:
  file.directory:
    - dir_mode: 0755
    - owner: root
    - group: root

supervisord:
  service:
    {%- if grains['os_family'] == 'Debian' %}
    - name: supervisor
    {%- elif grains['os_family'] == 'RedHat' %}
    - name: supervisord
    {%- endif %}
    - running
    - reload: True
    - enable: True
    - watch:
      - pip: supervisor
      - file: /etc/supervisord.conf
    - require:
      - file: /etc/supervisord.conf
      - file: /etc/init.d/supervisor
      - file: /var/log/supervisor
