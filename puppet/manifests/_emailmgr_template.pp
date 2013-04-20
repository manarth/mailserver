# -*- mode: ruby -*-
# vi: set ft=ruby :

###
# Email-manager specific configuration
###
node emailmgr_template {

  ###
  # The 'vmail' user will own the data-files.
  ###
  group { "vmail": 
    ensure => present,
    gid => '99',
    system => 'true',
  }
  user {'vmail':
    name => 'vmail',
    uid => '99',
    gid => '99',
    home => '/nonexistent',
    ensure => 'present',
    comment => 'Virtual mailbox user; owns groupware home directories.',
    system => 'true',
    shell => '/bin/false',
    require => Group['vmail'],
  }



  ###
  # Data-mount configuration
  ###

  # The home directory for each user should be:
  # /data/groupware/users/<username>/Maildir

  # Directory to store the mail. Will be a NAS mount.
  file {'/data':
    ensure => 'directory',
    owner => 'root',
    group => 'root',
    mode => '755',
  }
  file {'/data/groupware':
    ensure => 'directory',
    owner => 'root',
    group => 'root',
    mode => '755',
    require => File['/data'],
  }
  # Provide a /data/groupware/users directory, in case the NAS mount should fail.
  file {'/data/groupware/users':
    ensure => 'directory',
    owner => 'vmail',
    group => 'vmail',
    mode => '755',
    require => [
      File['/data/groupware'],
      User['vmail'],
    ],
  }


  package {'smbfs':}

  file {'/mnt/nasalot_groupware':
    ensure => 'directory',
    owner => 'vmail',
    group => 'vmail',
    mode => '755',
    require => User['vmail'],
  }

  mount {'nasalot':
    ensure => 'mounted',
    fstype => 'smbfs',
    name => '/mnt/nasalot_groupware',
    device => '//192.168.0.194/groupware',
    options => 'user=r_dovecot,password=dovepass,uid=vmail,gid=vmail',
    require => [
      File['/mnt/nasalot_groupware'],
      Package['smbfs'],
      User['vmail'],
    ],
  }

  # Bind /mnt/nasalot_groupware to /data/groupware
  exec { 'bind-testdata':
    command => 'mount --bind /mnt/nasalot_groupware /data/groupware',
    require => [
      Mount['nasalot'],
      File['/data/groupware/users'],
    ],
  }



  ###
  # Prepare the MySQL DB to hold the virtual email users.
  ###

  # Build MySQL and populate users.
  package {'mysql-server': }

  # Create database.
  exec {'mysql-create-dovecot-db':
    command => "mysql -e 'CREATE DATABASE groupware_users;'",
    require => Package['mysql-server'],
    unless => "mysql groupware_users -e 'SELECT 1=1'",
  }

  # Add the account that postfix will use to access the DB.
  exec { 'mysql-add-dovecot-user':
    command => "mysql -e 'GRANT ALL ON groupware_users.* to \"dovecot\"@\"localhost\" IDENTIFIED BY \"dovepass\";'",
    require => [
      Package['mysql-server'],
      Exec['mysql-create-dovecot-db'],
    ],
    path => ["/bin", "/usr/bin", "/usr/sbin"],
  }

  # Create the database table to store virtual users.
  exec {'mysql-populate-dovecot-db':
    command => "mysql groupware_users -e 'CREATE TABLE users (userid VARCHAR(128) NOT NULL, domain VARCHAR(128) NOT NULL, password VARCHAR(64) NOT NULL, home VARCHAR(255) NOT NULL);'",
    require => [
      Package['mysql-server'],
      Exec['mysql-create-dovecot-db'],
    ],
    path => ["/bin", "/usr/bin", "/usr/sbin"],
    unless => "mysql groupware_users -e 'SELECT COUNT(*) FROM users;'",
  }

  # Insert virtual users to the database.
  # Add standard personal account.
  exec { 'mysql-add-dovecot-mail-user':
    command => "mysql groupware_users -e 'INSERT INTO users (userid, domain, password, home) VALUES (\"marcus\", \"\", MD5(\"password\"), \"\");'",
    path => ["/bin", "/usr/bin", "/usr/sbin"],
    onlyif => "[ -z `mysql -N -s groupware_users -e 'SELECT NULL FROM users WHERE userid=\"marcus\";'` ]",
    require => [
      Exec['mysql-populate-dovecot-db'],
    ],
  }
  # Add TEST account.
  exec { 'mysql-add-dovecot-mail-user-test':
    command => "mysql groupware_users -e 'INSERT INTO users (userid, domain, password, home) VALUES (\"foo\", \"\", MD5(\"password\"), \"\");'",
    path => ["/bin", "/usr/bin", "/usr/sbin"],
    onlyif => "[ -z `mysql -N -s groupware_users -e 'SELECT NULL FROM users WHERE userid=\"foo\";'` ]",
    require => [
      Exec['mysql-populate-dovecot-db'],
    ],
  }


  ###
  # Configure dovecot.
  ###

  package { 'dovecot-core': }
  package { 'dovecot-imapd': }
  package { 'dovecot-postfix': }
  package { 'dovecot-managesieved': }
  package { 'dovecot-sieve': }
  package { 'dovecot-antispam': }
  package { 'dovecot-mysql': }
  package { 'postfix-mysql': }


  # Directory to store the dovecot mail indexes, for performance.
  # @TODO: Verify the owner.
  file {'/var/dovecot':
    ensure => 'directory',
    owner => 'root',
    group => 'root',
    mode => '755',
    require => Package['dovecot-core'],
  }
  file {'/var/dovecot/indexes':
    ensure => 'directory',
    owner => 'vmail',
    group => 'vmail',
    mode => '755',
    require => [
      File['/var/dovecot'],
      Package['dovecot-core'],
      User['vmail'],
    ],
  }


  # Set the mail location in conf.d/10-mail.conf
  # As the data is stored on a remote disk, store the indexes locally.
  line {'configure_mail_location':
    file => '/etc/dovecot/conf.d/10-mail.conf',
    line => 'mail_location = maildir:/data/groupware/users/%n/Maildir:INDEX=/var/dovecot/indexes/%u',
    ensure => 'present',
    require => [
      Package['dovecot-core'],
      File['/data/groupware/users'],
      File['/var/dovecot/indexes'],
    ],
  }
  line {'configure_mail_home':
    file => '/etc/dovecot/conf.d/10-mail.conf',
    line => 'mail_home = /data/groupware/users/%n',
    ensure => 'present',
    require => [ 
      Package['dovecot-core'],
      File['/data/groupware/users'],
    ],
  }



  ###
  # Use a preset user/group to own mail.
  ###
  line {'dovecot_configure_mail_uid':
    file => '/etc/dovecot/conf.d/10-mail.conf',
    line => 'mail_uid = vmail',
    ensure => 'present',
    require => [ 
      Package['dovecot-core'],
    ],
  }
  line {'dovecot_configure_mail_gid':
    file => '/etc/dovecot/conf.d/10-mail.conf',
    line => 'mail_gid = vmail',
    ensure => 'present',
    require => [ 
      Package['dovecot-core'],
    ],
  }
  line {'dovecot_allow_mail_user':
    file => '/etc/dovecot/conf.d/10-mail.conf',
    line => 'first_valid_uid = 99',
    ensure => 'present',
    require => [ 
      Package['dovecot-core'],
    ],
  }



  ###
  # Configure password-authentication.
  ###

  # Reference the auth-management file, in order to control dependencies
  file {'/etc/dovecot/conf.d/10-auth.conf':
    ensure => 'present',
    require => Package['dovecot-core'],
  }

  # Configure dovecot to use a new conf-file specifying SQL auth.
  line {'configure_auth_remove_default':
    file => '/etc/dovecot/conf.d/10-auth.conf',
    line => '!include auth-system.conf.ext',
    ensure => 'absent',
    require => File['/etc/dovecot/conf.d/10-auth.conf'],
  }
  line {'configure_auth_add_default_as_comment':
    file => '/etc/dovecot/conf.d/10-auth.conf',
    line => '#!include auth-system.conf.ext',
    ensure => 'present',
    require => Line['configure_auth_remove_default'],
  }
  line {'configure_auth_add_sql_conf':
    file => '/etc/dovecot/conf.d/10-auth.conf',
    line => '!include auth-sql.conf.ext',
    ensure => 'present',
    require => Line['configure_auth_add_default_as_comment'],
  }



  # Tell Dovecot to use SQL-auth, and where to find the SQL configuration file.
  file {'/etc/dovecot/conf.d/auth-sql.conf.ext':
    source => 'puppet:///modules/configurator/etc/dovecot/conf.d/auth-sql.conf.ext',
    ensure => 'file',
    owner => 'root',
    group => 'root',
    mode => '644',
    require => Package['dovecot-core'],
  }
  # Provide the MySQL configuration file.
  file {'/etc/dovecot/auth-sql.conf.ext':
    source => 'puppet:///modules/configurator/etc/dovecot/auth-sql.conf.ext',
    ensure => 'file',
    owner => 'root',
    group => 'root',
    mode => '644',
    require => Package['dovecot-core'],
  }




  # Attempt to ensure Dovecot restarts at the end of the provisioning process,
  # so that it includes all the custom configuration.
  service {'dovecot':
    ensure => 'running',
    require => [
      Line['configure_auth_add_sql_conf'],
      Package['dovecot-core'],
      File['/data/groupware/users', '/var/dovecot/indexes', '/etc/dovecot/auth-sql.conf.ext', '/etc/dovecot/conf.d/auth-sql.conf.ext']
    ],
    subscribe => [
      File['/etc/dovecot/conf.d/10-auth.conf'],
      Line['configure_auth_add_sql_conf'],
    ],
  }






  ###
  # Configure postfix
  ###

  # The postfix package will be installed by the package dovecot-postfix.


  # Provide the virtual-mailbox file that maps virtual users for Dovecot.
  file {'/etc/postfix/mysql_virtual_mailbox_maps.cf':
    source => 'puppet:///modules/configurator/etc/postfix/mysql_virtual_mailbox_maps.cf',
    ensure => 'file',
    owner => 'root',
    group => 'root',
    mode => '644',
    require => Package['dovecot-postfix'],
  }


  # Instruct postfix to use virtual users.
  line {'postfix_set_virtual_mailbox_base':
    file => '/etc/postfix/main.cf',
    line => 'virtual_mailbox_base = /data/groupware/users',
    ensure => 'present',
    require => Package['dovecot-postfix'],
  }
  line {'postfix_set_virtual_mailbox_maps':
    file => '/etc/postfix/main.cf',
    line => 'virtual_mailbox_maps = proxy:mysql:$config_directory/mysql_virtual_mailbox_maps.cf',
    ensure => 'present',
    require => Package['dovecot-postfix'],
  }

  # Set the user/group that owns the mailbox directories and contents.
  line {'postfix_virtual_uid_maps':
    file => '/etc/postfix/main.cf',
    line => 'virtual_uid_maps = static:99',
    ensure => 'present',
    require => Package['dovecot-postfix'],
  }
  line {'postfix_set_virtual_gid_maps':
    file => '/etc/postfix/main.cf',
    line => 'virtual_gid_maps = static:99',
    ensure => 'present',
    require => Package['dovecot-postfix'],
  }
  line {'postfix_set_virtual_minimum_uid':
    file => '/etc/postfix/main.cf',
    line => 'virtual_minimum_uid = 99',
    ensure => 'present',
    require => Package['dovecot-postfix'],
  }


  # Configure the virtual domain maps.
  line {'postfix_remove_mydestination':
    file => '/etc/postfix/main.cf',
    line => 'mydestination = vm-mailbox, localhost.localdomain, , localhost',
    ensure => 'absent',
    require => Package['dovecot-postfix'],
  }
  line {'postfix_set_mydestination':
    file => '/etc/postfix/main.cf',
    line => 'mydestination =',
    ensure => 'present',
    require => Package['dovecot-postfix'],
  }
  line {'postfix_set_virtual_mailbox_domains':
    file => '/etc/postfix/main.cf',
    line => 'virtual_mailbox_domains = vm-mailbox, localhost.localdomain, , localhost',
    ensure => 'present',
    require => Package['dovecot-postfix'],
  }
  line {'postfix_set_local_recipient_maps':
    file => '/etc/postfix/main.cf',
    line => 'local_recipient_maps = ',
    ensure => 'present',
    require => Package['dovecot-postfix'],
  }
  
  


  # 
  # 
  # 


  # Configure postfix to deliver to dovecot.
  # ==========================================================================
  # service type  private unpriv  chroot  wakeup  maxproc command + args
  #               (yes)   (yes)   (yes)   (never) (100)
  # ==========================================================================
  line {'postfix_configure_dovecot_delivery':
    file => '/etc/postfix/master.cf',
    line => 'dovecot  unix  - n n - - pipe  flags=DRhu  user=vmail:vmail  argv=/usr/lib/dovecot/deliver -d $(recipient)',
    ensure => 'present',
    require => Package['dovecot-postfix'],
  }




  ##
  # Configure fetchmail
  ##

  package {'fetchmail':}

  line {'remove_fetchmail_default_conf':
    file => '/etc/default/fetchmail',
    line => 'START_DAEMON=no',
    ensure => 'absent',
    require => Package['fetchmail'],
  }
  line {'add_fetchmail_default_conf':
    file => '/etc/default/fetchmail',
    line => 'START_DAEMON=yes',
    ensure => 'present',
    require => Package['fetchmail'],
  }
  file {'/etc/fetchmailrc':
    source => 'puppet:///modules/configurator/etc/fetchmailrc',
    ensure => 'file',
    owner => 'root',
    group => 'root',
    mode => '600',
    require => Package['fetchmail'],
  }




  ##
  # Allow read-access to the mail logs.
  ##
  file {'/var/log/mail.err':
    mode => '644',
    require => Package['dovecot-core'],
  }
  file {'/var/log/mail.log':
    mode => '644',
    require => Package['dovecot-core'],
  }

}
