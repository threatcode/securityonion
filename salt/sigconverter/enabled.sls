# Copyright Security Onion Solutions LLC and/or licensed to Security Onion Solutions LLC under one
# or more contributor license agreements. Licensed under the Elastic License 2.0 as shown at 
# https://securityonion.net/license; you may not use this file except in compliance with the
# Elastic License 2.0.

{% from 'allowed_states.map.jinja' import allowed_states %}
{% if sls.split('.')[0] in allowed_states %}
{%   from 'vars/globals.map.jinja' import GLOBALS %}
{%   from 'docker/docker.map.jinja' import DOCKER %}
{%   from 'sigconverter/map.jinja' import SIGCONVERTERMERGED %}

include:
  - ssl

{%   if SERVICETOKEN != '' %}
so-sigconverter:
  docker_container.running:
    - image: {{ GLOBALS.registry_host }}:5000/{{ GLOBALS.image_repo }}/so-sigconverter:{{ GLOBALS.so_version }}
    - name: so-sigconverter
    #- hostname: FleetServer-{{ GLOBALS.hostname }}
    - detach: True
    - user: 947
    - networks:
      - sobridge:
        - ipv4_address: {{ DOCKER.containers['so-sigconverter'].ip }}
    - extra_hosts:
        - {{ GLOBALS.manager }}:{{ GLOBALS.manager_ip }}
        - {{ GLOBALS.hostname }}:{{ GLOBALS.node_ip }}
        {% if DOCKER.containers['so-sigconverter'].extra_hosts %}
          {% for XTRAHOST in DOCKER.containers['so-sigconverter'].extra_hosts %}
        - {{ XTRAHOST }}
          {% endfor %}
        {% endif %}
    - port_bindings:
      {% for BINDING in DOCKER.containers['so-sigconverter'].port_bindings %}
      - {{ BINDING }}
      {% endfor %}
    - binds:
      - /opt/so/log/sigconverter:/usr/share/logs
     {% if DOCKER.containers['so-sigconverter'].custom_bind_mounts %}
        {% for BIND in DOCKER.containers['so-sigconverter'].custom_bind_mounts %}
      - {{ BIND }}
        {% endfor %}
      {% endif %}      
    - environment:
      - LOGS_PATH=logs
      {% if DOCKER.containers['so-sigconverter'].extra_env %}
        {% for XTRAENV in DOCKER.containers['so-sigconverter'].extra_env %}
      - {{ XTRAENV }}
        {% endfor %}
      {% endif %}
{%   endif %}

delete_so-sigconverter_so-status.disabled:
  file.uncomment:
    - name: /opt/so/conf/so-status/so-status.conf
    - regex: ^so-sigconverter$


{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
