Background
==========

This setup came about from several requirements:

* I have POP3 accounts with a bunch of ISPs/providers.
* I want to access my email through IMAP.
* I want to access my email from various computers, tablets, phones, etc.
* I want control of my email. I do not want to use some 'cloud'.
* I want my email access to be encrypted.
* I want to funnel my various POP3 accounts into either a personal mail 
  account, or a business mail account.

I built a VM to do this many years ago, before I ever started using puppet.  
I started planning to build a puppet-recipe to rebuild it all, and then
procrastinated for a year. Of course, Murphey's law then demanded its due, and
blew up the VM's host. To top it off, I'm working abroad right now and didn't
have time to fix the hardware properly, so grabbed the disks and ran.

Technically, I guess I could have just recovered the VM from the disk image,
but that wouldn't have been anywhere near as much fun!

So here's what I've built.


About
=====

This VM provides:

* Dovecot, to provide IMAP accounts for your email.
* Fetchmail, to retrieve emails from remote servers.
* Postfix, to deliver mail from Fetchmail to Dovecot.
* Seive, for automatic mail-filtering.


Some comments about my setup:

* Data is stored on my NAS. It's called *Nasalot*. Yes, I am **that** imaginative.
* The NAS is mounted on /data/groupware.
* Dovecot users are authenticated via MySQL.


Support
=======

This setup is mostly for me, so it's not very well documented, and I'm not
particularly planning on spending time supporting it. However, I probably will
improve the documentation over time, and I'll review and merge pull-requests -
if they're any good :-)


Security
========

This setup includes weak/example passwords, and a few bad practices, not least
in the puppet recipe. In my case, it's running on my home network behind NAT,
so is fairly hard to get to. I might get around to Doing It Right(TM) at some
point, but in the meantime, be warned: here be dragons!

