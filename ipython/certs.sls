

# http://docs.saltstack.com/en/latest/ref/modules/all/salt.modules.tls.html
#
# /etc/pki/{{ certcfg["ca_name"] }}/certs/{{ certcfg["CN"] }}.{crt, key}

{% from "ipython/map.jinja" import cacfg with context %}
{% from "ipython/map.jinja" import certcfg with context %}

python-openssl:
  pkg.installed: []

ipython-ca:
  module:
    - run
    - name: tls.create_ca
    - ca_name: {{ cacfg["ca_name"] }}
    - bits: {{ cacfg["bits"] }}
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

ipython-server-cert-csr:
  module:
    - run
    - name: tls.create_csr # TODO
    - ca_name: {{ certcfg["ca_name"] }}
    - bits: {{ cacfg["bits"] }}
    - days: {{ certcfg["days"] }}
    - CN: {{ certcfg["CN"] }}
    - C: {{ cacfg["C"] }}
    - ST: {{ cacfg["ST"] }}
    - L: {{ cacfg["L"] }}
    - O: {{ cacfg["O"] }}
    - OU: {{ cacfg["OU"] }}
    - emailAddress: {{ cacfg["emailAddress"] }} 
    #- subjectAltName: ['DNS:ipython.{# domain #}']
    #-cacert_path: 

  - require:
    - module: ipython-ca

ipython-server-cert:
  module:
    - run
    - name: tls.create_ca_signed_cert
    - ca_name: {{ certcfg["ca_name"] }}
    - require:
      - module: ipython-server-cert-csr

