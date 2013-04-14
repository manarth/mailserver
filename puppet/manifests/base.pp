# -*- mode: ruby -*-
# vi: set ft=ruby :


# Load the global common configuration that all boxes use.
import "_common.pp"

# Load the ldap configuration.
import "_ldap_template.pp"

# Apply the LDAP template to all nodes here.
node default inherits ldap_template { }
