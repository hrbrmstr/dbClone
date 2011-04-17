This is a non-Python (all native Objecive-C) version of Moloch''s dbClone
utility that demonstrates the insecurity of Dropbox installations.

This is a very basic release that does not have all the functionality of
Moloch''s version (yet).

As of version 0.1, you can:

* View local Dropbox hostId & user e-mail
* Send that data to a remote host
* Copy (append) that data to a file
* Make a backup copy of your Dropbox config.db file

There are two additional keys in the application''s property list (dbClone-Info.plist):

* "MothershipURL" - the URL of the remote host you want to store the cloned info to. It defaults to http://somesite.domain/mothership.php to avoid accidentally sending your own Dropbox data to a remote host.
* "LogFilename" - _just_ the filename you want to use when storing the clones info to locally. It defaults to the top-level of the mounted volume (the original Linux & Windows dbClone was meant to be run from a USB/external volume) or "~/" if running it on your boot drive.

If you do use the backup option, the current naming scheme is "backup-config.db" and it''s important to note that the program will not attempt to overwrite the file. I may change that behaviour in an upcoming release.

I tested the build on OS X 10.6.7 but the Xcode project is set to build for compatibility with 10.5.x or 10.6.x. Feedback on behaviour on other systems would be most welcome.
