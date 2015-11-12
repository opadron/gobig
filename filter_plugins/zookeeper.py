
"""Filter plugins for supporting the zookeeper and mesos roles."""


def zk_url(host_list, host_vars, net_interface, client_port):
    """Compute the zookeeper url corresponding to the given list of hosts.

    :param host_list: the list of ansible hosts to include in the result
    :type  host_list: str
    :param host_vars: ansible host_vars object
    :type  host_vars: dict
    :param net_interface: the net interface from which to sample IP addresses
    :type  net_interface: str
    :param client_port: port on which each host is listening for zookeeper
                        connections
    :type  client_port: int

    :returns: the zookeeper url corresponding the given list of hosts
    """
    net_interface_key = "ansible_{}".format(net_interface)
    return "".join((
        "zk://",
        ":{},".format(str(client_port)).join(
            host_vars[host][net_interface_key]["ipv4"]["address"]
            for host in host_list
        ),
        ":",
        str(client_port),
    ))


class FilterModule(object):
    """Ansible filter module class."""

    def filters(self):
        """Return the filter v-table."""
        return {"zk_url": zk_url}

