
# ipython-formula/ipython/init.sls
#

{% from "ipython/map.jinja" import ipython with context %}

# http://docs.saltstack.com/en/latest/ref/states/all/salt.states.pkgrepo.html#module-salt.states.pkgrepo
# { Docker os defaults (would be in map.jinja) }


# repo-xyz:
#   pkgrepo.managed:
#     - 

# http://docs.saltstack.com/en/latest/ref/states/all/salt.states.pkg.html#module-salt.states.pkg

ipython-system-packages:
  pkg.installed:
    pkgs:
      - {{ ipython.nbpkg2 }}
      - {{ ipython.nbpkg3 }}

include:
{# if TODO: if not defined(pip2) #}
  - ipython.pip
{# endif #}
{%- if use_supervisord %}
  - ipython.supervisord
{% endif %}

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

group-ipython:
  group.present:
    - name: ipython
    - system: False


# http://docs.saltstack.com/en/latest/ref/states/all/salt.states.user.html#module-salt.states.user
{# see: pillar #}
{% set ipy_users=["ipy",] %}
{% for ipyuser in ipy_users %}
{%- set homedir="/home/{0}".format(ipyuser) %}
{%- set notebookdir="/home/{0}/notebooks".format(ipyuser) %}
{%- set cachedir="/home/{0}/.cache/pip".format(ipyuser) %}
{%- set supervisord_conf="/etc/supervisord/conf.d/ipython-user_{0}.conf".format(ipyuser) %}

{%- set ipythondir="/home/{0}/.ipython".format(ipyuser) %}

{%- set virtualenvdir="{0}/env".format(homedir) %}
{%- set ipythonbindir="{0}/bin".format(virtualenvdir) %}
{%- set ipythonbin="{0}/ipython".format(ipythonbindir) %}

{%- set ipythoncluster_n="2" %}

{# TODO: Generate a stable UUID (across restarts)
{%- set ipythonidentfile="ipython.uuid" %}
ipython-{{ ipyuser }}-uuid:
  cmd.run:
    - name: uuidgen >> {{ ipythonidentfile }}
    - creates: {{ ipythonidentfile }}

#}
{%- set ipythonident="C9A2D170-46B8-4AAF-840A-0292D" -%}

{%- set ipythoncertfile="{0}/.ssl/localcert.pem".format(ipythondir) -%}


user-{{ ipyuser }}:
  user.present:
    - name: {{ ipyuser }}
    - gid_from_name: True
    - groups:
      - ipython
    #- removegroups: True
    - home: {{ homedir }}
    - createhome: True
    - shell: /bin/bash
    - require:
      - group: group-ipython


ipython-notebook-directory:
  file.directory:
    - name: {{ notebookdir }}
    - owner: {{ ipyuser }}
    - dir_mode: 0755
    - require:
      - user: user-{{ ipyuser }}

# Pip install
ipython-{{ ipyuser }}-pip:
  pip.installed:
    - name: ipython
    - user: {{ ipyuser }}

# http://docs.saltstack.com/en/latest/ref/states/all/salt.states.virtualenv_mod.html#module-salt.states.virtualenv_mod

pip-cachedir-{{ ipyuser }}:
  file.directory:
    - name: {{ cachedir }}
    - user: {{ ipyuser }}
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

{% if use_supervisord %}
# http://docs.saltstack.com/en/latest/ref/states/all/salt.states.supervisord.html#module-salt.states.supervisord
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
      [program:ipnb]
      user={{ ipyuser }}
      command={{ ipythonbindir }}/ipython --notebook \
        --secure \
        --notebook-dir={{ notebookdir }}
        --ipython-dir={{ ipythondir }} \
        --no-browser \
        --ident={{ ipythonident }} \
        --certfile={{ ipythoncertfile }}
      strip_ansi=True
      autostart=True
      autorestart=True
      numprocs=1

      [program:ipcluster]
      user={{ ipyuser }}
      command={{ ipythonbindir }}/ipcluster \
        start \
        --n={{ ipythoncluster_n }} \
        --ipython-dir={{ ipythondir }} \
        --work-dir={{ ipythondir }}/work
      strip_ansi=True
      autostart=True
      autorestart=True
      numprocs=1

  include:
    - ipython.certs

{% endif %}

{% endfor %}

# http://docs.saltstack.com/en/latest/ref/states/all/salt.states.service.html#module-salt.states.service
# { services: ipython[-notebook], [ supervisord-ipython / ipython-supervisord / ipy ] }

