##################################################################
# Serial Port Monitor for Windows, Linux, Solaris
# (c) rs@rolf-schroedter.de http://www.rolf-schroedter.de/moni
##################################################################
# $Id: tty.tcl 1456 2009-12-21 13:45:01Z schroedt $
##################################################################
# Sample TTY plugin
# - defines TTY callbacks ::tty::input & ::tty::key
##################################################################

namespace eval ::tty {}

##################################################################
# ::tty::key key txt
#    Parameters:
#	key	- Input key
#	txt	- Text widget (TTY ascii) for displaying input
#    Returns:
#	str	- String to send to target system via RS-232
#		  (usually the same $key)
##################################################################
proc ::tty::key { key txt } {
#    string toupper $key
    set key
}

##################################################################
# ::tty::symbol sym txt
#    Parameters:
#	sym	- Input symbol (special key like cursor)
#	txt	- Text widget (TTY ascii) for displaying input
#    Returns:
#	str	- String to send to target system via RS-232
#		  (can be a translated $key)
##################################################################
proc ::tty::symbol { sym txt } {
    #
    # Hack for Cursor keys
    # According to the standard text bindings we translate cursor keys:
    #     Up    ^P   \x10
    #     Down  ^N   \x0E
    #     Left  ^B   \x02
    #     Right ^F   \x06
    #
    switch -- $sym {
	Up	{ return \x10 }
	Down	{ return \x0E }
	Left	{ return \x02 }
	Right	{ return \x06 }
	default { return ""   }
    }

}

##################################################################
# ::tty::input str txt
#    Parameters:
#	str	- String received from target system via RS-232
#	txt	- Text widget (TTY ascii) for displaying input
#    Returns:
#	<nothing>
##################################################################
proc ::tty::input { str txt } {

    #
    # 1. Replace all bells by a single bell
    #
    if { [regsub -all {\x07} $str "" str] } {
	# string contains BELL
	bell
    }
    #
    # 2. Remove all control characters which we are ignoring
    #
    if { [regsub -all {[\x01-\x06\x09\x0B-\x1F]} $str "" str] } {
	# do nothing
    }
    #
    # 3. If there a no more control characters, then make a single text insert.
    #    -This makes processing of long input strings much faster.
    #    - \x0A (NEWLINE) is allowed for fast text insert.
    #
    if { [regexp -all {[\x08]} $str] == 0 } {
	$txt insert end $str
	return
    }
    #
    # 4. If there are still some control characters left,
    #    we need to process character-by-character.
    #    - Currently this is needed for BACKSPACE processing only...
    #
    foreach ch [split $str {}] { ;# short (slow) data input

        switch -regexp -- $ch {
        \x08    {   ;# Don't delete over End-of-Line
                    set col [lindex [split [$txt index insert] . ] 1]
                    if { $col } {$txt delete end-2c}
                }
        default {
                    $txt insert end $ch
                }
        } ;# switch
    } ;# foreach
}


proc ::tty::init {} {
    #
    # Add some initialization code here
    #
}

::tty::init
