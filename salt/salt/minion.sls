{% from 'vars/globals.map.jinja' import GLOBALS %}
{% from 'salt/map.jinja' import UPGRADECOMMAND with context %}
{% from 'salt/map.jinja' import SALTVERSION %}
{% from 'salt/map.jinja' import INSTALLEDSALTVERSION %}
{% from 'salt/map.jinja' import SALTPACKAGES %}
{% from 'salt/map.jinja' import SYSTEMD_UNIT_FILE %}
{% import_yaml 'salt/minion.defaults.yaml' as SALTMINION %}
{% set service_start_delay = SALTMINION.salt.minion.service_start_delay %}

include:
  - salt.python_modules
  - salt
  - systemd.reload
  - repo.client
  - salt.mine_functions
{% if GLOBALS.role in GLOBALS.manager_roles %}
  - ca
{% endif %}

{% if INSTALLEDSALTVERSION|string != SALTVERSION|string %}

{# this is added in 2.4.120 to remove salt repo files pointing to saltproject.io to accomodate the move to broadcom and new bootstrap-salt script #}
{%   if salt['pkg.version_cmp'](GLOBALS.so_version, '2.4.120') == -1 %}
{%     set saltrepofile = '/etc/yum.repos.d/salt.repo' %}
{%     if grains.os_family == 'Debian' %}
{%       set saltrepofile = '/etc/apt/sources.list.d/salt.list' %}
{%     endif %}
remove_saltproject_io_repo_minion:
  file.absent:
    - name: {{ saltrepofile }}
{%   endif %}

unhold_salt_packages:
  pkg.unheld:
    - pkgs:
{% for package in SALTPACKAGES %}
      - {{ package }}
{% endfor %}

install_salt_minion:
  cmd.run:
    - name: |
        exec 0>&- # close stdin
        exec 1>&- # close stdout
        exec 2>&- # close stderr
        nohup /bin/sh -c '{{ UPGRADECOMMAND }}' &

{% endif %}

{% if INSTALLEDSALTVERSION|string == SALTVERSION|string %}

hold_salt_packages:
  pkg.held:
    - pkgs:
{% for package in SALTPACKAGES %}
      - {{ package }}: {{SALTVERSION}}-0.*
{% endfor %}

remove_error_log_level_logfile:
  file.line:
    - name: /etc/salt/minion
    - match: "log_level_logfile: error"
    - mode: delete

remove_error_log_level:
  file.line:
    - name: /etc/salt/minion
    - match: "log_level: error"
    - mode: delete

set_log_levels:
  file.append:
    - name: /etc/salt/minion
    - text:
      - "log_level: info"
      - "log_level_logfile: info"

enable_startup_states:
  file.uncomment:
    - name: /etc/salt/minion
    - regex: '^startup_states: highstate$'
    - unless: pgrep so-setup

# prior to 2.4.30 this managed file would restart the salt-minion service when updated
# since this file is currently only adding a sleep timer on service start
# it is not required to restart the service
salt_minion_service_unit_file:
  file.managed:
    - name: {{ SYSTEMD_UNIT_FILE }}
    - source: salt://salt/service/salt-minion.service.jinja
    - template: jinja
    - defaults:
        service_start_delay: {{ service_start_delay }}
    - onchanges_in:
      - module: systemd_reload

{% endif %}

# this has to be outside the if statement above since there are <requisite>_in calls to this state
salt_minion_service:
  service.running:
    - name: salt-minion
    - enable: True
    - onlyif: test "{{INSTALLEDSALTVERSION}}" == "{{SALTVERSION}}"
    - listen:
      - file: mine_functions
{% if INSTALLEDSALTVERSION|string == SALTVERSION|string %}
      - file: set_log_levels
{% endif %}
{% if GLOBALS.role in GLOBALS.manager_roles %}
      - file: /etc/salt/minion.d/signing_policies.conf
{% endif %}
    - order: last
