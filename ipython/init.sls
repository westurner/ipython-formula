
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

{% if use_supervisord %}
include:
  - ipython.supervisord
{% endif %}

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

group-ipython:
  group.present:
    - name: ipython
    - system: False


# http://docs.saltstack.com/en/latest/ref/states/all/salt.states.user.html#module-salt.states.user
{# see: pillar #}
{% set ipy_users=["ipy",] %}
{% for ipyuser in ipy_users %}

user-{{ ipyuser }}:
  user.present:
    - name: {{ ipyuser }}
    - gid_from_name: True
    - groups:
      - ipython
    #- removegroups: True
    - home: /home/{{ ipyuser }}
    - createhome: True
    - shell: /bin/bash
    - require:
      - group: group-ipython



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

{% if use_supervisord %}
{%- set supervisord_conf="/etc/ipython/sites-enabled/user_{0}.conf".format(ipyuser) %}
# http://docs.saltstack.com/en/latest/ref/states/all/salt.states.supervisord.html#module-salt.states.supervisord
ipython-{{ ipyuser }}-server:
  supervisord:
    - running
    - require:
      - pkg: supervisor
    - watch:
      - file: {{ supervisord_conf }}

{%- set ipythondir="/home/{0}/.ipython".format(ipyuser) %}
{# TODO: Generate a stable UUID (across restarts): salt.$(uuidgen) #}
{%- set ipythonident="C9A2D170-46B8-4AAF-840A-0292D" -%}
{%- set ipythoncertfile="{0}/.ssl/localcert.pem".format(ipythondir) -%}

{%- set ipythonbindir="/home/{0}/env/bin" %}
{%- set ipythonbin="{0}/ipython".format(ipythonbindir) %}

{%- set ipythoncluster_n="2" %}

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

# http://docs.saltstack.com/en/latest/ref/modules/all/salt.modules.tls.html

python-openssl:
  pkg.installed: []

{% set cacfg={
  "ca_name": "Example CA",
  "bits": 2048,
  "days": 3650,
  "country": "US",
  "CN": "Root CA"
  "C": "C",
  "ST": "ST",
  "L": "L",
  "O": "O",
  "OU": "OU",
  "emailAddress": "example@example.org"
} %}

ipython-ca:
  module:
    - run
    - name: tls.create_ca
    - bits: {{ cacfg["bits"] }}
    - ca_name: {{ cacfg["ca_name"] }}
    - days: {{ cacfg["days"] }}
    - CN: {{ cacfg["CN"] }}
    - C: {{ cacfg["C"] }}
    - ST: {{ cacfg["ST"] }}
    - L: {{ cacfg["L"] }}
    - O: {{ cacfg["O"] }}
    - OU: {{ cacfg["OU"] }}
    - emailAddress: {{ cacfg["emailAddress"] }} 
    - require:
      - pkg: python-openssl

{% set certcfg={
  "ca_name": cacfg["ca_name"],
  "CN": "example.org",
  "days": 365,

} %}

ipython-server-cert:
  module:
    - run
    - name: tls.create_ca_signed_cert
    - ca_name: {{ certcfg["ca_name"] }}

# /etc/pki/{{ certcfg["ca_name"] }}/certs/{{ certcfg["CN"] }}.crt
#
#

{% endif %}

{% endfor %}

# http://docs.saltstack.com/en/latest/ref/states/all/salt.states.service.html#module-salt.states.service
# { services: ipython[-notebook], [ supervisord-ipython / ipython-supervisord / ipy ] }

