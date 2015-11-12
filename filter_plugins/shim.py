
"""Filter plugins implementing filters present in upcomming releases."""


def regex_escape(string):
    """Return the given string after escaping any regex characters.

    :param string: input string
    :type  string: str

    :returns: the given string after escaping any regex characters
    """
    from re import escape
    return escape(string)


class FilterModule(object):
    """Ansible filter module class."""

    def filters(self):
        """Return the filter v-table."""
        return {"regex_escape": regex_escape}

