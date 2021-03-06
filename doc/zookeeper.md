
### zookeeper
Provisions and manages a zookeeper node

#### Variables

|Name                            |Default        |Description                                                                  |
|:-------------------------------|:-------------:|:----------------------------------------------------------------------------|
|recompile                       |false          |whether to force recompilation of zookeeper's C bindings                     |
|state                           |started        |state of the service                                                         |
|zookeeper_ansible_group         |(required)     |ansible group name for the zookeeper nodes                                   |
|zookeeper_autopurge             |false          |whether to purge old snapshots and transaction logs                          |
|zookeeper_autopurge_interval    |1              |autopurge interval (in ticks)                                                |
|zookeeper_autopurge_retain      |3              |number of the most recent snapshots and transaction logs to retain           |
|zookeeper_client_port           |2181           |port on which to listen to client connections                                |
|zookeeper_crypt_pass            |(generated)    |hash of the password to use for the user                                     |
|zookeeper_data_root             |(generated)    |root directory for the zookeeper data files                                  |
|zookeeper_group                 |zookeeper      |group to run the zookeeper service as                                        |
|zookeeper_init_limit            |10             |duration within which nodes in a quorum must connect to the leader (in ticks)|
|zookeeper_install_root          |(generated)    |root directory to install zookeeper under                                    |
|zookeeper_max_client_connections|128            |maximum number of simultaneous client connections                            |
|zookeeper_net_interface         |eth0           |interface on which to bind                                                   |
|zookeeper_sync_limit            |5              |maximum duration by which nodes in a quorum may be out of date (in ticks)    |
|zookeeper_tick_time             |2000           |duration of one "tick" (in milliseconds)                                     |
|zookeeper_user                  |zookeeper      |user to run the zookeeper service as                                         |
|zookeeper_version               |3.4.6          |version of zookeeper to deploy                                               |

#### Notes

  - `state` can be any one of "absent", "present", "stopped", "started",
    "reloaded", or "restarted".

  - By default, the hash for a blank password is used when creating
    a new zookeeper user, disabling password login.

  - By default, zookeeper is installed under /opt/zookeeper/`zookeeper-version`.

  - By default, zookeeper's data is stored under
    /data/zookeeper/`zookeeper-version`.

  - The `zookeeper_ansible_group` variable provides zookeeper nodes with
    awareness of each other, which is necessary for configuration and
    management.

  - The zookeeper documentation suggests using an odd-number of zookeeper nodes
    in an ensemble.

#### Examples

Install/Configure/Start
```YAML
  - hosts: zookeepers
    roles:
      - role: zookeeper
        zookeeper_ansible_group: zookeepers
        state: started
```

Stop/Remove
```YAML
  - hosts: zookeepers
    roles:
      - role: zookeeper
        zookeeper_ansible_group: zookeepers
        state: absent
```

