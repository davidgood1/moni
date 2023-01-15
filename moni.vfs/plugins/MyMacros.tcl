##################################################################
# Serial Port Monitor for Windows, Linux, Solaris
# (c) Rolf.Schroedter@web.de http://www.rolf-schroedter.de/moni
##################################################################
# $Id: MyMacros.tcl 1495 2010-09-03 06:23:57Z schroedt $
##################################################################
# Send a string with repetition & delay
# - Moni2.30 adds rudimentary support for user-plugins.
# - This file may be used as a sample plugin.
# - It's recommended to create an own namespace to avoid conflicts
#   with future versions of Moni.
# - For adding menu entries its recommended to use the "plugins"
#   menuid.
##################################################################

namespace eval ::myMacros {
    set S(Data)         {}      ;# File contents
    set S(Progress)     {}      ;# Progress status
    set S(Sending)      0       ;# Write operation pending

    set S(History)      10      ;# Max 10 history entries for input combobox

    set S(Next.Char)    0       ;# Next char may be written
    set S(Next.String)  0       ;# Next string may be written

    set S(Char.Delay)   0       ;# Delay between sending two characters
    set S(String.Delay) 1000    ;# Delay between string repetitions
    set S(String.Count) 1       ;# Repeat counter for sending string, 0=endless

    set S(String.Type)  ascii   	;# Default string type
    set S(String.Ascii) "foo bar "	;# ASCII string to be sent
    set S(String.Hex)   "31 32 33"	;# HEX string to be sent

    set S(Win.Ascii)	?	;# The ComboBox widget for Ascii strings
    set S(Win.Hex)	?	;# The ComboBox widget for Hex strings

    set S(Echo.Enable)  	0	;# Enable echo server (default must be 0)
    set S(Echo.Busy)		0	;# Echo server: Busy flag
    set S(Echo.Buf)		{}	;# Echo server: Buffer of characters to echo

    set S(Echo.Delay)		0	;# Echo server delay
    set S(Echo.Char.Delay)	0	;# Echo server delay for each character
    set S(Echo.Next.Char)    	0       ;# Next char may be written

    set S(Echo.Err)  		0	;# Enable echo errors
    set S(Echo.Err.Missing)	1	;# 10% missing characters
    set S(Echo.Err.Replace)	1	;# 10% replace random characters
    set S(Echo.Err.nMissed)	0	;# Number of missed characters
    set S(Echo.Err.nReplaced)	0	;# Number of replaced characters
    set S(Echo.Err.strMissed)	" -- "	;# Message about missed characters
    set S(Echo.Err.strReplaced)	" -- "	;# Message about replaced characters

    set S(Echo.Rx)		0	;# Echo server: number of received characters
    set S(Echo.Tx)		0	;# Echo server: number of echoed characters
}

###############################################################################
# Simple HEX validation
#
# Checking event="focusout" is optional,
# it can be removed together with the event parameter
#
# Sample application:
#    entry .e2 -validate key -vcmd {validInteger %W %P %s -256 +1024}
###############################################################################
proc ::myMacros::valid_hex {win event X oldX} {

    # Weak integer checking: allow empty string, 4-digit hex numbers, spaces
    set weakCheck [regexp {^([ 0-9a-fA-F]*)?$} $X]

    # if weak check fails, continue with old value
    if {! $weakCheck} {set X $oldX}

    switch $event {
        focusout -
        key {
            return $weakCheck
        }
        default {
            return 1
        }
    }
}

###############################################################################
# Add ComboBox history
# - Add an item to the top of the command list
# - If an item already exists, then delete it first
# - Limit the history size to max. N entries
###############################################################################
proc ::myMacros::add_history { cb val } {
    variable S

    set vList [$cb cget -values]
    set idx [lsearch -exact $vList $val]
    if { $idx >= 0 } {
	set vList [lreplace $vList $idx $idx]
    }
    set vList [linsert $vList 0 $val]
    if {[llength $vList] > $S(History)} {
	set vList [lreplace $vList $S(History) end]
    }
    $cb configure -values $vList
}

###############################################################################
# Send a HEX or ASCII string
###############################################################################
proc ::myMacros::send_string { data } {
    variable S

    # Sending a string with/without character delay
    #
    if { $::myMacros::S(Char.Delay) } {

        # Start write operation, character per character
        #
        foreach ch [split $data {}] {
            ::moni::rs232_put $ch
            after $S(Char.Delay) {incr ::myMacros::S(Next.Char)}
            tkwait variable ::myMacros::S(Next.Char)

            if {! $S(Sending)} return   ;# return if stopped
        }
    } else {

        # Start write operation, nonblocking in background
        #
        ::moni::rs232_put $data

        # Setup notifier for end of write operation
        # Wait until write operation finished
        # Remove notifier
        #
        fileevent $::moni::M(Chan) writable {incr ::myMacros::S(Next.Char)}
        tkwait variable ::myMacros::S(Next.Char)
        fileevent $::moni::M(Chan) writable {}
    }
}

proc ::myMacros::send_all {} {
    variable S

    # Allow only one sending process
    #
    if { $S(Sending) } {
        return
    }
    # Error message if serial port not open.
    #
    if { ! $::moni::M(Open) } {
        ::moni::error_ret "Serial port not open"
    }

    # Send the same string with optional repetition
    #
    set S(Sending)  1
    set S(Progress) ""

    switch -- $S(String.Type) {
	ascii {
	    add_history $S(Win.Ascii) $S(String.Ascii)
	    set data $S(String.Ascii)
	}
	hex {
	    #
	    # Remove all spaces and interpret the string as hex
	    #
	    add_history $S(Win.Hex) [string trim $S(String.Hex)]
	    set hex [regsub -all {[ ]} $S(String.Hex) {}]
	    set data [binary format H* $hex]
	}
	default {
	    return
	}
    }

    set i 0
    while { ($S(String.Count) == 0) || ($i < $S(String.Count))} {
        ::myMacros::send_string $data$S(String.EOL)

        if {! $S(Sending)} return   ;# return if stopped

        after $S(String.Delay) {incr ::myMacros::S(Next.String)}
        tkwait variable ::myMacros::S(Next.String)

        if {! $S(Sending)} return   ;# return if stopped

        incr i
        set S(Progress) [format "%d / %d" $i $S(String.Count)]
    }
    stop
}

proc ::myMacros::stop {} {
    variable S

    # Stop sending
    # Send signals to pending background processes
    #
    set S(Sending)     0        ;# Stop sending
    set S(Next.Char)   1        ;# Signal end of S(Char.Delay)
    set S(Next.String) 1        ;# Signal end of S(String.Delay)
}

###############################################################################
# Echo error
# - Insert errors into echo data
###############################################################################
proc ::myMacros::echo_insert_errors {data} {
    variable S

    set result {}

    foreach ch [split $data {}] {
	#
	# Percent missing bytes
	#
	if { $S(Echo.Err.Missing) } {
	    if { 100*rand() < $S(Echo.Err.Missing) } {
		#
		# Missing the current character
		#
		incr S(Echo.Err.nMissed)
		binary scan $ch c x
		set S(Echo.Err.strMissed)  [format " (%02X-->x)" [expr {$x & 0xFF}]]
		continue
	    }
	}
	#
	# Percent replaced (random invalid) bytes
	#
	if { $S(Echo.Err.Replace) } {
	    if { 100*rand() < $S(Echo.Err.Replace) } {
		#
		# Replace the current character
		#
		incr S(Echo.Err.nReplaced)
		set y [expr {int(256*rand())}]

		binary scan $ch c x
		set S(Echo.Err.strReplaced)  [format " (%02X-->%02X)" [expr {$x & 0xFF}] $y]
		set ch [binary format c $y]
	    }
	}
	append result $ch
    }
    set result
}

###############################################################################
# Echo a string
# - Similar to the ::myMacros::send_string function
# - Echo strings must be buffered, otherwise concurrent echo procedures are started
###############################################################################
proc ::myMacros::echo_send {} {
    variable S

    #
    # Avoid double-invocation of echo_send.
    # This may happen, when we are sending characters with delay,
    # because the buffer gets refilled before we are ready.
    #
    if { $S(Echo.Busy) } {
	return
    }
    set S(Echo.Busy) 1

    # We need to make sure to send all characters ***in the correct order***
    # In each loop we grap the complete buffer and send it.
    # When we are ready, we re-check the buffer for new data.
    #
    while { [string length $S(Echo.Buf)] } {
	set data $S(Echo.Buf)
	set S(Echo.Buf)  {}

	#
	# Optionally insert data errors
	#
	if { $S(Echo.Err) } {
	    set data [::myMacros::echo_insert_errors $data]
	}

	#
	# Sending a string with/without character delay
	#
	if { $S(Echo.Char.Delay) } {
	    #
	    # Start write operation, character per character
	    #
	    foreach ch [split $data {}] {
		incr S(Echo.Tx) 1
	       ::moni::rs232_put $ch
		after $S(Echo.Char.Delay) {incr ::myMacros::S(Echo.Next.Char)}
		tkwait variable ::myMacros::S(Echo.Next.Char)
	    }
	} else {
	    #
	    # Start write operation, nonblocking in background
	    #
	    incr S(Echo.Tx) [string length $data]
	    ::moni::rs232_put $data
	}
    }
    set S(Echo.Busy) 0
}

proc ::myMacros::echo_reset {} {
    variable S

    if { $S(Echo.Enable) } {
	set S(Echo.Buf) 		{}
	set S(Echo.Rx)  		0
	set S(Echo.Tx)  		0
	set S(Echo.Err.nMissed)		0
	set S(Echo.Err.nReplaced)	0
	set S(Echo.Err.strMissed)	" -- "
	set S(Echo.Err.strReplaced)	" -- "
    }
}

proc ::myMacros::echo_callback { data } {
    variable S

    if { $S(Echo.Enable) } {
	incr S(Echo.Rx) [string length $data]
	append S(Echo.Buf) $data
	after $S(Echo.Delay) ::myMacros::echo_send
    }
}

###############################################################################
# Create the Send-String & ECHO window
###############################################################################
#
proc ::myMacros::win { {win .my_macros} } {
    variable S

    catch { destroy $win }
    toplevel $win
    wm title $win "Macros"

    set mf [MainFrame $win.frame]
    pack $mf -fill both -expand yes

    $mf addindicator -textvariable ::myMacros::S(Progress) -width 20

    # NoteBook creation
    #
    set notebook [NoteBook $mf.nb]

    # Send file notebook page
    #
    set nb [$notebook insert end sendfile -text "Send String"]

        TitleFrame $nb.file -text "Data" -side left -borderwidth 1
        set f [$nb.file getframe]

            radiobutton $f.r1 -text "Ascii" \
                -variable ::myMacros::S(String.Type) -value ascii
                DynamicHelp::register $f.r1 balloon "ASCII string type"

            ComboBox $f.c1 -expand tab \
                -textvariable ::myMacros::S(String.Ascii) -editable 1 \
                -values {} \
                -helptext "ASCII string to send."

            radiobutton $f.r2 -text "Hex" \
                -variable ::myMacros::S(String.Type) -value hex
                DynamicHelp::register $f.r2 balloon "Hexadecimal string input"

            ComboBox $f.c2 -expand tab \
                -textvariable ::myMacros::S(String.Hex) -editable 1 \
                -values {} \
                -validate all -vcmd {::myMacros::valid_hex %W %V %P %s} \
                -helptext "HEX string to send."

                grid $f.r1 $f.c1 -sticky news -pady 2
                grid $f.r2 $f.c2 -sticky news -pady 2
                grid columnconfigure $f 1 -weight 1

        set S(Win.Ascii) $f.c1
        set S(Win.Hex)   $f.c2

        TitleFrame $nb.opts -text "Options" -side left -borderwidth 1
        set f [$nb.opts getframe]

            set f1 [frame $f.eol]
            pack $f1 -side left

                Label $f1.t1 -text "EOL: "   \
                    -helptext "Select end of line option"

                radiobutton $f1.r1 -text "<none>" \
                    -variable ::myMacros::S(String.EOL) -value ""
                DynamicHelp::register $f1.r1 balloon "No end-of-line characters are sent"

                radiobutton $f1.r2 -text "CRLF" \
                    -variable ::myMacros::S(String.EOL) -value "\x0D\x0A"
                DynamicHelp::register $f1.r2 balloon "DOS-style CR,LF are sent after each string"

                radiobutton $f1.r3 -text "LF" \
                    -variable ::myMacros::S(String.EOL) -value "\x0A"
                DynamicHelp::register $f1.r3 balloon "UNIX-style LF is sent after each string"

                radiobutton $f1.r4 -text "CR" \
                    -variable ::myMacros::S(String.EOL) -value "\x0D"
                DynamicHelp::register $f1.r4 balloon "CR is sent after each string"

                pack $f1.t1 $f1.r1 $f1.r2 $f1.r3 $f1.r4 -side left -padx 2

            Label $f.t1 -text "Repeat: " -anchor w  \
                -helptext "Repeat counter for sending the same string.\n(0= send forever)"
            SpinBox $f.sb1 \
                -textvariable ::myMacros::S(String.Count) \
                -width 8 -editable 1 -range {0 1000000 1} \
                -helptext [$f.t1 cget -helptext]

            Label $f.t2 -text "Char Delay: " -anchor w  \
                -helptext "Delay between sending two characters in milliseconds\nWarning: Implemented as Tcl after delay, not very accurate."
            SpinBox $f.sb2 \
                -textvariable ::myMacros::S(Char.Delay) \
                -width 8 -editable 1 -range {0 10000 1} \
                -helptext [$f.t2 cget -helptext]

            Label $f.t3 -text "String Delay: " -anchor w  \
                -helptext "Delay between string repetitions in milliseconds"
            SpinBox $f.sb3 \
                -textvariable ::myMacros::S(String.Delay) \
                -width 8 -editable 1 -range {0 3600000 10} \
                -helptext [$f.t3 cget -helptext]

            Button $f.send -text "Send" -helptext "Start sending the data string" \
                -width 10 -command ::myMacros::send_all
            Button $f.stop -text "Stop" -helptext "Stop sending" \
                -width 10 -command ::myMacros::stop

	    grid $f.eol  -       -  -       -sticky news -pady 2
	    grid $f.t1   $f.sb1  x  $f.send -sticky news -pady 2
	    grid $f.t2   $f.sb2  x  $f.stop -sticky news -pady 2
	    grid $f.t3   $f.sb3  x  x       -sticky news -pady 2
	    grid columnconfigure $f 2 -weight 1 -minsize 10

	grid $nb.file  -  x  -sticky news
	grid $nb.opts  -  x  -sticky news
	grid columnconfigure $nb 2 -weight 1

    # Echo server notebook page
    #
    set nb [$notebook insert end dump -text "Echo server"]

        TitleFrame $nb.opts -text "Options" -side left -borderwidth 1
        set f [$nb.opts getframe]

	    checkbutton $f.c1 -text "Enable" \
		-variable ::myMacros::S(Echo.Enable)	\
		-command  ::myMacros::echo_reset
	    DynamicHelp::register $f.c1 balloon "Enable/Disable echo server"

            Label $f.t2 -text "Char Delay: " -anchor w  \
                -helptext "Delay between sending two characters in milliseconds\nWarning: Implemented as Tcl after delay, not very accurate."
            SpinBox $f.sb2 \
                -textvariable ::myMacros::S(Echo.Char.Delay) \
                -width 8 -editable 1 -range {0 10000 1} \
                -helptext [$f.t2 cget -helptext]

            Label $f.t3 -text "String Delay: " -anchor w  \
                -helptext "Send delay of the complete input"
            SpinBox $f.sb3 \
                -textvariable ::myMacros::S(Echo.Delay) \
                -width 8 -editable 1 -range {0 3600000 10} \
                -helptext [$f.t3 cget -helptext]

	    grid $f.c1   -       x  -sticky nws -pady 2
	    grid $f.t2   $f.sb2  x  -sticky news -pady 2
	    grid $f.t3   $f.sb3  x  -sticky news -pady 2
	    grid columnconfigure $f 2 -weight 1 -minsize 10

        TitleFrame $nb.errs -text "Errors" -side left -borderwidth 1
        set f [$nb.errs getframe]

	    checkbutton $f.c1 -text "Errors" \
		-variable ::myMacros::S(Echo.Err)
	    DynamicHelp::register $f.c1 balloon "Enable/Disable echo errors"

            Label $f.t2 -text "Missing chars (%): " -anchor w  \
                -helptext "Percent of missing characters"
            SpinBox $f.sb2 \
                -textvariable ::myMacros::S(Echo.Err.Missing) \
                -width 8 -editable 1 -range {0 100 1} \
                -helptext [$f.t2 cget -helptext]

            Label $f.t3 -text "Replace chars (%): " -anchor w  \
                -helptext "Percent of charcaters replace by random characters"
            SpinBox $f.sb3 \
                -textvariable ::myMacros::S(Echo.Err.Replace) \
                -width 8 -editable 1 -range {0 100 1} \
                -helptext [$f.t3 cget -helptext]

	    grid $f.c1   -       x  -sticky nws -pady 2
	    grid $f.t2   $f.sb2  x  -sticky news -pady 2
	    grid $f.t3   $f.sb3  x  -sticky news -pady 2
	    grid columnconfigure $f 2 -weight 1 -minsize 10

        TitleFrame $nb.stats -text "Statistics" -side left -borderwidth 1
        set f [$nb.stats getframe]

            Label $f.t1 -text "Received: " -anchor w  \
                -helptext "Number of received bytes"
            Label $f.v1 -textvariable ::myMacros::S(Echo.Rx) -anchor w  \
                -helptext [$f.t1 cget -helptext]

            Label $f.t2 -text "Echoed: " -anchor w  \
                -helptext "Number of echoed bytes"
            Label $f.v2 -textvariable ::myMacros::S(Echo.Tx) -anchor w  \
                -helptext [$f.t2 cget -helptext]

	    grid $f.t1   $f.v1  x  -sticky news -pady 2
	    grid $f.t2   $f.v2  x  -sticky news -pady 2
	    grid columnconfigure $f 2 -weight 1 -minsize 10

        TitleFrame $nb.errstat -text "Error Stats" -side left -borderwidth 1
        set f [$nb.errstat getframe]

            Label $f.t1 -text "Missed: " -anchor w  \
                -helptext "Number of missed bytes"
            Label $f.v1 -textvariable ::myMacros::S(Echo.Err.nMissed) -anchor w  \
                -helptext [$f.t1 cget -helptext]
            Label $f.s1 -textvariable ::myMacros::S(Echo.Err.strMissed) -anchor w  \
                -helptext [$f.t1 cget -helptext]

            Label $f.t2 -text "Replaced: " -anchor w  \
                -helptext "Number of replaced bytes"
            Label $f.v2 -textvariable ::myMacros::S(Echo.Err.nReplaced) -anchor w  \
                -helptext [$f.t2 cget -helptext]
            Label $f.s2 -textvariable ::myMacros::S(Echo.Err.strReplaced) -anchor w  \
                -helptext [$f.t1 cget -helptext]

	    grid $f.t1   $f.v1  $f.s1  x  -sticky news -pady 2
	    grid $f.t2   $f.v2  $f.s2  x  -sticky news -pady 2
	    grid columnconfigure $f 3 -weight 1 -minsize 10

	grid $nb.opts  $nb.errs     x  -sticky news
	grid $nb.stats $nb.errstat  x  -sticky news
	grid columnconfigure $nb 2 -weight 1


    # NoteBook display
    #
    $notebook compute_size
    pack $notebook -fill both -expand yes -padx 4 -pady 4
    $notebook raise [$notebook page 0]

    ::moni::center_top $win
}


proc ::myMacros::init {} {
    #
    # Add a menu entry for the S-Record loader
    #
    set menu [.moni getmenu plugins]
    $menu add command -label "My macros" -command ::myMacros::win

    #
    # Register the INOUT callback for the Echo Server
    #
    ::moni::callback input ::myMacros::echo_callback
}

::myMacros::init
