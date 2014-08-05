
# Apache 2.0
# supervisord config courtesy of saltstack-formulas/graphite-formula 

# http://docs.saltstack.com/en/latest/ref/states/all/salt.states.pkgrepo.html#module-salt.states.pkgrepo
# { Docker os defaults (would be in map.jinja) }

# repo-xyz:
#   pkgrepo.managed:
#     - 

# http://docs.saltstack.com/en/latest/ref/states/all/salt.states.pkg.html#module-salt.states.pkg

ipython-system-packages:
  pkg.installed:
    pkgs:
      - ipython-notebook
      - ipython3-notebook

python2-pip:
  pkg.installed:
    - python-pip

supervisor:
  pkg.installed:
    - supervisor

/etc/supervisor.conf:
  file.managed:
    - mode: 0644
    - contents: |
        ; supervisor config file

        ; [unix_http_server]
        ; file=/var/run//supervisor.sock   ; (the path to the socket file)
        ; chmod=0700                       ; sockef file mode (default 0700)

        [supervisord]
        logfile=/var/log/supervisor/supervisord.log ; (main log file;default $CWD/supervisord.log)
        pidfile=/var/run/supervisord.pid ; (supervisord pidfile;default supervisord.pid)
        childlogdir=/var/log/supervisor            ; ('AUTO' child log dir, default $TEMP)

        ; the below section must remain in the config file for RPC
        ; (supervisorctl/web interface) to work, additional interfaces may be
        ; added by defining them in separate rpcinterface: sections
        [rpcinterface:supervisor]
        supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

        [supervisorctl]
        serverurl=unix:///var/run//supervisor.sock ; use a unix:// URL  for a unix socket

        ; The [include] section can just contain the "files" setting.  This
        ; setting can list multiple files (separated by whitespace or
        ; newlines).  It can also contain wildcards.  The filenames are
        ; interpreted as relative to this file.  Included files *cannot*
        ; include files themselves.

        [include]
        files = /etc/supervisor/conf.d/*.conf

#/etc/init.d/supervisor:
#  file.managed:
#    - source: /etc/init.d/supervisor  # (pkg)
#    - source: salt://ipython/files/supervisord.init.sh

{%- set pip_cachedir="/var/cache/pip" %}
pip-cachedir-system:
  file.directory:
    - name: {{ pip_cachedir }}
    - dir_mode: 0755
    #- owner: root
    #- group: root  # pip?
    ##- file_mode: 0644
    ##- recurse: True

{%- set pip_requirements="requirements.txt" %}

ipython-pip-system-packages:
  pip.installed:
    - requirements: salt://requirements.txt
    - pip_download_cache: {{ pip_cachedir }}
    - require:
      - file: {{ pip_cachedir }}
    # requirements.txt
    # conda
    # enstaller
    # ... requirements-sci_xyz.txt
    # numpy
    # scipy
    # matplotlib
    # pandas
    # scikit-learn


# http://docs.saltstack.com/en/latest/ref/states/all/salt.states.user.html#module-salt.states.user
{# see: pillar #}
{% set ipy_users=["ipy",] %}
{% for user in ipy_users %}

ipython-user:
  user.todo:
    - name: {{ ipyuser }}

{%- set notebookdir="/home/{0}/notebooks".format(ipyuser) %}
ipython-notebook-directory:
  file.directory:
    - name: {{ notebookdir }}
    - owner: {{ ipyuser }}
    - dir_mode: 0755
    - require:
      - user: {{ ipyuser }}

# Pip install
ipython-{{ ipyuser }}-pip:
  pip.installed:
    - name: ipython
    - user: {{ ipyuser }}
    - require:
      - pkg: python-pip

# http://docs.saltstack.com/en/latest/ref/states/all/salt.states.virtualenv_mod.html#module-salt.states.virtualenv_mod
{%- set cachedir="/home/{0}/.cache/pip" %}

pip-cachedir-{{ ipyuser }}:
  file.directory:
    - name: {{ cachedir }}
    - owner: {{ ipyuser }}
    - dir_mode: 0755
    - makedirs: True


virtualenv-user-{{ ipyuser }}:
  virtualenv.managed:
    - name: /home/{{ ipyuser }}/env
    - runas: {{ ipyuser }}
    - requirements: salt://requirements.txt
    # - requirements: salt://requirements-sci_xyz.txt
    - system_site_packages: False  #
    - use_wheel: True
    - pip_download_cache: {{ cachedir }}
    - require:
      - file: pip-cachedir-{{ ipyuser }}
    
# http://docs.saltstack.com/en/latest/ref/states/all/salt.states.pip_state.html

{%- set supervisord_conf="/etc/ipython/sites-enabled/user_{0}.conf".format(ipyuser) %}
ipython-{{ ipyuser }}-server:
  supervisord:
    - running
    - require:
      - pkg: supervisor
    - watch:
      - file: {{ supervisord_conf }}

ipython-{{ ipyuser }}-supervisord_conf:
  file.managed:
    - name: {{ supervisord_conf }}
    - content: |
      
      # Supervisord.conf
      [program:ipynb]
      command=/path/to/ipython --notebook \
        --secure \
        --notebook-dir={{ notebookdir }}
        --ipython-dir={{ ipythondir }} # TODO

      [program:ipycluster]
      command=/path/to/ipython 
      # TODO


{% endfor %}

# http://docs.saltstack.com/en/latest/ref/states/all/salt.states.supervisord.html#module-salt.states.supervisord
{ instances: ipynb, ipycluster }

# http://docs.saltstack.com/en/latest/ref/states/all/salt.states.service.html#module-salt.states.service
{ services: ipython[-notebook], [ supervisord-ipython / ipython-supervisord / ipy ] }

