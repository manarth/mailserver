# -*- mode: ruby -*-
# vi: set ft=ruby :

# Author: PuppetLabs
# Source: http://projects.puppetlabs.com/projects/1/wiki/simple_text_patterns

define line($file, $line, $ensure = 'present') {
    case $ensure {
        default : { err ( "unknown ensure value ${ensure}" ) }
        present: {
            exec { "/bin/echo '${line}' >> '${file}'":
                unless => "/bin/grep -qFx '${line}' '${file}'"
            }
        }
        absent: {
            exec { "phpundeprecate $file":
              command => "sed -i 's/^${line}$//' $file",
              path => ["/bin", "/usr/bin", "/usr/sbin"],
            }
        }
    }
}
