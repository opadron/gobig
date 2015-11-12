
"""Filter plugins for supporting the ec2-pod role."""


def flatten_ec2_result(ec2_result):
    """Turn the results returned from the ec2 module into a flat table.

    The input results are from a multi-run of the ec2 module using the with_dict
    clause.  The returned table is a list of dictionaries - one for each created
    instance, with the following keys:
      - hostname: public dns name of the instance
      - id: internal id by which the instance must be referred when making
        subsequent AWS API calls
      - groups: list of ansible groups the instance should be made a member of

    :param ec2_result: the results from the ec2 module
    :type  ec2_result: dict

    :returns: the flattened table
    """
    result = []
    for entry in ec2_result["results"]:
        for instance in entry["tagged_instances"]:
            result.append({"hostname": instance["public_dns_name"],
                           "id": instance["id"],
                           "groups": entry["item"]["value"]["groups"]})

    return result


def process_hosts_spec(hosts_spec, pod_name):
    """Transform a hosts specification.

    Transforms a hosts specification object into a format suitable for use with
    the ec2 module.  The return value is a dictionary of objects to be used in
    an invocation of the ec2 module using the with_dict clause.

    :param hosts_spec: the hosts specification object
    :type  hosts_spec: dict
    :param pod_name: the name of the pod being managed
    :type  pod_name: str

    :returns: the transformed hosts specification
    """
    result = {}
    for key, value in hosts_spec.items():
        value["groups"] = list(set(value.get("groups", ())) |
                               set((pod_name,)))

        if "volumes" in value:
            new_volumes = []
            for volume_name, volume_size in value["volumes"].items():
                new_volumes.append({"delete_on_termination": True,
                                    "device_name": "/dev/" + volume_name,
                                    "volume_size": volume_size})

            value["volumes"] = new_volumes

        result[key] = value

    return result


def compute_ec2_update_lists(pod_name,
                             hosts_spec,
                             state,
                             region,
                             default_ssh_key,
                             default_image,
                             default_instance_type):
    """Compute ec2 update lists.

    Computes the update lists for the given pod.  The lists are a dictionary
    with two keys, "start" and "terminate", mapping to a list of the instance
    IDs for the instances that are to be started (after being created, if
    necessary) and terminated, respectively.

    The update lists are determined based on the hosts specification and the
    desired as well as current states of the pod's instances.  Wherever
    possible, instances that have already been created are preferentially
    identified for reuse instead of being terminated and subsequently recreated.

    :param pod_name: name of the pod
    :type  pod_name: str
    :param hosts_spec: hosts specification
    :type  hosts_spec: dict
    :param state: desired state of the pod's instances
    :type  state: str
    :param region: AWS region
    :type  region: str
    :param default_ssh_key: default ssh key name
    :type  default_ssh_key: str
    :param default_image: default AWS AMI image
    :type  default_image: str
    :param default_instance_type: default ec2 instance type
    :type  default_instance_type: str

    :returns: the dictionary of update lists
    """
    from collections import defaultdict
    from itertools import chain
    from boto import ec2

    conn = ec2.connect_to_region(region)
    if conn is None:
        raise Exception(" ".join((
            "region name:",
            region,
            "likely not supported, or AWS is down."
            "connection to region failed.")))

    reservations = conn.get_all_instances()

    # short-circuit the case where the pod should be terminated
    if state == "absent":
        return {"start": [], "terminate": list(set(
            chain.from_iterable(
                (instance.id for instance in reservation.instances
                 if instance.tags.get("ec2_pod") == pod_name)
                for reservation in reservations)
        ))}

    ec2_host_table = defaultdict(lambda: defaultdict(set))
    for reservation in reservations:
        for instance in reservation.instances:
            if instance.tags.get("ec2_pod") != pod_name:
                continue

            if instance.state not in ("running", "stopped"):
                continue

            instance_name = instance.tags.get("ec2_pod_instance_name")
            composite_key = (unicode(instance_name),
                             unicode(instance.key_name),
                             unicode(instance.image_id),
                             unicode(instance.instance_type))

            ec2_host_table[composite_key][instance.state].add(instance.id)

    host_counter_table = dict(
        ((unicode(key),
          unicode(value.get("ssh_key", default_ssh_key)),
          unicode(value.get("image", default_image)),
          unicode(value.get("type", default_instance_type))),
         value.get("count", 1))
        for key, value in hosts_spec.items())

    start_set = set()
    terminate_set = set()

    for composite_key, sets in ec2_host_table.items():
        running_list = list(sets["running"])
        stopped_list = list(sets["stopped"])

        num_running = len(running_list)

        num_wanted = host_counter_table.get(composite_key, 0)

        num_to_keep = min(num_running, num_wanted)
        num_to_start = num_wanted - num_to_keep

        start_set |= set(stopped_list[:num_to_start])

        terminate_set |= set(stopped_list[num_to_start:])
        terminate_set |= set(running_list[num_to_keep:])

    return {"start": list(start_set), "terminate": list(terminate_set)}


def get_ec2_hosts(instance_table):
    """Return the list of instance IDs from a flattened ec2 result table.

    :param instance_table: flattened table of ec2 results such as those returned
                           from flatten_ec2_result
    :type  instance_table: list

    :returns: the list of instance IDs
    """
    import operator as op
    return map(op.itemgetter("id"), instance_table)


class FilterModule(object):
    """Ansible filter module class."""

    def filters(self):
        """Return the filter v-table."""
        return {"compute_ec2_update_lists": compute_ec2_update_lists,
                "flatten_ec2_result": flatten_ec2_result,
                "get_ec2_hosts": get_ec2_hosts,
                "process_hosts_spec": process_hosts_spec}

