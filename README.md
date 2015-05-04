# SCRinhibit
A bash script to keep screensavers on Linux systems from appearing under certain circumstances

## What it does?
SCRinhibit runs as a background process (or not, if you want to debug it) and executes a loop on a regular basis, checking for applications, which are entered on a blacklist, either for mere existence of the process or for having a window running in fullscreen.

If SCRinhibit finds one of the "blacklisted" processes, it will attempt inhibit to keep the screensaver from appearing. The screensaver will, however, not be inhibited, if it is already running, e.g. if the user locks the screen manually.

SCRinhibit supports an additional battery profile, in which other processes can be specified, which block the screensaver from appearing when running on battery power, which allows a more fine-grained configuration.

## What Screensavers are supported?
Currently, the following screensavers are supported. To specify the screensaver, a three-letter-acronym is used, which stands before the screensaver name.

- `cin`    cinnamon-screensaver
- `kde`    KDE4 screensaver (may as well work for others)
- `xsc`    xscreensaver
- `gno`    gnome-screensaver (may, too, work for others)

As a kind of "fallback", a call to `xdg-screensaver` is supported, which may work with some screensavers.

## Why is "my" screensaver not supported?
Either I don't know of its existence or I haven't yet figured out how to communicate with it. If you know an unsupported screensaver, please be so nice and create a new feature request or pull request.

#How do I start it?

    scrinhibit.sh -s <screensaver acronym> -i <interval in seconds> -c </path/to/blacklist/files>

The script will automatically daemonize itself. To run it in the foreground, use the `-d` switch. You may want to enable verbose output using the `-v` switch, too.

## How do the blacklists work?
There are at least two blacklists: `procblacklist.conf` and `fsblacklist.conf`, which have to be in the same directory (specifiable by `-c`). Each file contains process names, newline-separated. These names will be used to match against currently running processes, and the screensaver will be inhibited if a process entered in `procblacklist.conf` is running or a process entered in `fsblacklist.conf` is running a fullscreen X window.

Additionaly, two more blacklists can be used: `battery_procblacklist.conf` and `battery_fsblacklist.conf`. These files will be considered instead of the two above if and only if both files are present and no AC adapter is attached.

Have a look at the example .conf files. When using these files, the screensaver is inhibited, if (only looking at AC power now) `vlc` or `totem` processes exist or if `chrome` or `firefox` processes have a fullscreen window. Note that, even if Chrome is executed using the command `google-chrome` or `google-chrome-whatever-channel-you are-using`, the process owning the window is still named `chrome`.

Note that only certain parts of the process command will be checked, e.g. when the command name (obtained from `ps x`) is

    /usr/bin/someapp --some-switches some args
    
then only `someapp` will be compared to the blacklists, any arguments, directories and switches will be ignored. This means the script currently doesn't work with bash scripts, because the command would be `/bin/bash /some/script.sh`

## Dependencies?

- A screensaver (Who would have guessed?)
- BASH (of course)
- qdbus
- wmctrl
- acpi
- probably some other stuff I installed and forgot about.

## Like it? Hate it? Want to make it better?
Create an issue and scream and shout!
