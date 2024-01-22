# Copyright Security Onion Solutions LLC and/or licensed to Security Onion Solutions LLC under one
# or more contributor license agreements. Licensed under the Elastic License 2.0 as shown at
# https://securityonion.net/license; you may not use this file except in compliance with the
# Elastic License 2.0.

{% from 'allowed_states.map.jinja' import allowed_states %}
{% if sls.split('.')[0] in allowed_states %}
{%   from 'vars/globals.map.jinja' import GLOBALS %}
{%   from 'docker/docker.map.jinja' import DOCKER %}
{%   from 'soc/merged.map.jinja' import DOCKER_EXTRA_HOSTS %}

include:
  - soc.config
  - soc.sostatus

so-soc:
  docker_container.running:
    - image: {{ GLOBALS.registry_host }}:5000/{{ GLOBALS.image_repo }}/so-soc:{{ GLOBALS.so_version }}
    - hostname: soc
    - name: so-soc
    - networks:
      - sobridge:
        - ipv4_address: {{ DOCKER.containers['so-soc'].ip }}
    - binds:
      - /nsm/soc/jobs:/opt/sensoroni/jobs:rw
      - /nsm/soc/uploads:/nsm/soc/uploads:rw
      - /opt/so/log/soc/:/opt/sensoroni/logs/:rw
      - /opt/so/conf/soc/soc.json:/opt/sensoroni/sensoroni.json:ro
      - /opt/so/conf/soc/motd.md:/opt/sensoroni/html/motd.md:ro
      - /opt/so/conf/soc/banner.md:/opt/sensoroni/html/login/banner.md:ro
      - /opt/so/conf/soc/custom.js:/opt/sensoroni/html/js/custom.js:ro
      - /opt/so/conf/soc/custom_roles:/opt/sensoroni/rbac/custom_roles:ro
      - /opt/so/conf/soc/soc_users_roles:/opt/sensoroni/rbac/users_roles:rw
      - /opt/so/conf/soc/queue:/opt/sensoroni/queue:rw
      - /opt/so/saltstack:/opt/so/saltstack:rw
    - extra_hosts:
    {% for node in DOCKER_EXTRA_HOSTS %}
    {%   for hostname, ip in node.items() %}
      - {{hostname}}:{{ip}}
    {%   endfor %}
    {% endfor %}
    {% if DOCKER.containers['so-soc'].extra_hosts %}
    {%   for XTRAHOST in DOCKER.containers['so-soc'].extra_hosts %}
      - {{ XTRAHOST }}
    {%   endfor %}
    {% endif %}
    - port_bindings:
    {% for BINDING in DOCKER.containers['so-soc'].port_bindings %}
      - {{ BINDING }}
    {% endfor %}
    {% if DOCKER.containers['so-soc'].extra_env %}
    - environment:
    {%   for XTRAENV in DOCKER.containers['so-soc'].extra_env %}
      - {{ XTRAENV }}
    {%   endfor %}
    {% endif %}
    - watch:
      - file: /opt/so/conf/soc/*
    - require:
      - file: socdatadir
      - file: soclogdir
      - file: socconfig
      - file: socmotd
      - file: socbanner
      - file: soccustom
      - file: soccustomroles
      - file: socusersroles

delete_so-soc_so-status.disabled:
  file.uncomment:
    - name: /opt/so/conf/so-status/so-status.conf
    - regex: ^so-soc$

salt-relay:
  cron.present:
    - name: '/opt/so/saltstack/default/salt/soc/files/bin/salt-relay.sh &'
    - identifier: salt-relay

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
