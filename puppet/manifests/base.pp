# -*- mode: ruby -*-
# vi: set ft=ruby :


# Load the global common configuration that all boxes use.
import "_common.pp"

# Load the email-manager configuration.
import "_emailmgr_template.pp"

# Apply the email-manager template to all nodes here.
node default inherits emailmgr_template { }
