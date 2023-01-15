##################################################################
# Serial Port Monitor for Windows, Linux, Solaris
# (c) rs@rolf-schroedter.de http://www.rolf-schroedter.de/moni
##################################################################
# $Id: Moni-Term.tcl 1474 2010-04-21 11:43:19Z schroedt $
##################################################################

############# Serial port timer event (ticker) #################
# ::moni::ticker
#
proc ::moni::ticker {} {
    variable M

    ::moni::update_status
    after $M(Term.Ticker) ::moni::ticker
}

############# Terminal read fileevent #################
# ::moni::reader
#       Serial fileevent handler
#
proc ::moni::reader {} {
    variable M
    if { [catch {read $M(Chan)} str] } {
        incr M(TTY.Errors)
        if { [catch {fconfigure $M(Chan) -lasterror} M(TTY.LastError)] } {
            set M(TTY.LastError) "read error"
        }
#        ::moni::config_reopen  ;# error ??? unknown option fconfigure -buffering none
#        ::moni::error_ret $str
    } else {
        incr M(Term.TotalCount) [string length $str]
        if { $M(Term.Log) } {
            ::moni::log_out $str
        }
        if { ! $M(Term.Stop) } {
            ::moni::tty_in $str
            ::moni::raw_in $str
	    #
	    # Execute User input callback
	    #
        ::moni::exec_callbacks input $str
        }
    }
    ::moni::update_status
    update idletasks    ;# display changes
}

############# Terminal wait for write operation to finish #################
# ::moni::wait_write
#
proc ::moni::writable {} {
    variable M
    set M(Term.Writing) 0       ;# can be traced with vwait variable
}

############# Terminal input/output #################

proc ::moni::rs232_put { str } {
    variable M

    if { ! $M(Open) } {
        bell
        return
    }
    if { $M(Term.Echo) } {

        # We want to see the "echo" in log-file, if enabled.
        # Write log-file before sending, because sending might be delayed
        # (think about "Edit/Paste")
        #
        if { $M(Term.Log) } {
            ::moni::log_out $str
        }
        ::moni::tty_in $str
        ::moni::raw_in $str
    }
    #
    # Execute User output callback
    # then physically Write the string to the serial port
    #
    ::moni::exec_callbacks output $str
    puts -nonewline $M(Chan) $str
}
proc ::moni::term_cutLines { txt maxLines } {
    if { ($maxLines > 0) } {
        set lines [lindex [split [$txt index end] . ] 0]
        if { $lines > $maxLines } {
            $txt delete 1.0 [expr {1 + $lines - $maxLines + $maxLines/10} ].0
        }
    }
}
proc ::moni::term_clear {} {
    variable M

    $M(Win.TTY) delete 1.0 end
    $M(Win.Raw.Hex) delete 1.0 end
    $M(Win.Raw.Ascii) delete 1.0 end
    set M(Term.Count) 0
    set M(Term.TotalCount) 0
    ::moni::raw_insert_count
}

############# TTY terminal ##########################
#
# Event handler for TTY-input: a key is pressed
# Checks whether it is a printable, sends key to Rs232
# Return flag, whether key has been processed (to prevent further processing by def. handler)
#
######################################################################
# Default output character callback,
# - used if no tty::input callback defined by user plugin
######################################################################
proc ::moni::tty_out { key sym } {
    variable M

    #
    # Special handling for special keys (Cursors, etc)
    # - Call a user-defines special key handler.
    #
    if { [string length $key] == 0 } {
	if {[llength [info commands ::tty::symbol]]} {
	    set key [::tty::symbol $sym $M(Win.TTY)]
	}
    } else {
	#
	# Call user-defined key handler, if exists
	#
	if {[llength [info commands ::tty::key]]} {
	    set key [::tty::key $key $M(Win.TTY)]
	}
    }
    if {[string length $key]} {
        ::moni::rs232_put $key
    }
    return 1   ;# process all keys
}
proc ::moni::tty_key { win key sym } {
    if { [moni::tty_out $key $sym] } { ;# if key has been processed
        $win see end
        return -code break
    } else {                         ;# key not processed
        return -code continue        ;# process by default handler
    }
}

######################################################################
# Default input character callback,
# - used if no tty::input callback defined by user plugin
######################################################################
# Interpretation of single characters is too slow in tcl
# Large strings:
#   assumption: do not contain BackSpace,etc.
#   process them via [regsub]
# Short strings:
#   process them character by character
#   this allows BackSpace interpretation
######################################################################
proc ::moni::default_tty_input { str txt } {

    if { [string length $str] > 10 } {  ;# long(fast) data input

        regsub -all "\[\x01-\x06\x08-\x09\x0B-\x1F\]" $str "" str
        if { [regsub -all "\x07" $str "" str] } {   ;# string contains BELL
            bell
        }
        $txt insert end $str

    } else { foreach ch [split $str {}] { ;# short (slow) data input

        switch -regexp -- $ch {
            [\x01-\x06\x09\x0B-\x1F]
                {       ;# ignore
                }
            \x07
                {       ;# <Bell>
                    bell
                }
            \x08
                {   ;#### MSDOS: at end there is 0D0A -> end-2c
                    if { [$txt compare end != 1.0] } {$txt delete end-2c}
                }
            \x0A
                {
                    $txt insert end $ch
                }
            default
                {
                    $txt insert end $ch
                }
        } ;# switch
    } } ;# else foreach
}

proc ::moni::tty_in { str } {
    variable M

    # Call existing user-defined callback
    # or Moni's default callback
    #
    if {[llength [info commands ::tty::input]]} {
        ::tty::input $str $M(Win.TTY)
    } else {
        ::moni::default_tty_input $str $M(Win.TTY)
    }

    # Cut text contents if too long
    # and show end of text
    #
    ::moni::term_cutLines $M(Win.TTY) $M(Term.MaxLines)
    if { ! $M(Term.Hold) } {
        $M(Win.TTY) see end              ;# adjust view to text end
        $M(Win.TTY) mark set insert end  ;# set insertion cursor to text end
    }
}

############# RAW (Hex) terminal ##########################
#
# Event handler for Hex-input: a key is pressed
# Checks whether it is a printable, sends key to Rs232
# Return flag, whether key has been processed (to prevent further processing by def. handler)
#
proc ::moni::raw_key { win key sym } {
    variable M
    if { [regexp {[0-9A-Fa-f]} $key] } {
        if { [string length $M(Win.Raw.Input)] == 2 } {
            set M(Win.Raw.Input) {}
        }
        append M(Win.Raw.Input) $key
        if { [string length $M(Win.Raw.Input)] == 2 } {
            set ch [binary format H2 $M(Win.Raw.Input)]
            ::moni::rs232_put $ch
            $M(Win.Raw.Input.W) configure -bg white
        } else {
            $M(Win.Raw.Input.W) configure -bg yellow
        }
    } else {
        bell
    }
    return -code break
}
proc ::moni::raw_insert_count {} {
    variable M
    $M(Win.Raw.Hex) insert end [format "%08X: " $M(Term.Count)]
}
proc ::moni::raw_in { str } {
    variable M

    foreach ch [split $str {}] {
        binary scan $ch c1 value
        set value [expr ($value + 0x100) % 0x100]
        $M(Win.Raw.Hex) insert end [format "%02X " $value]
        regsub -all "\[\x00-\x1F\\x7F-\xFF]" $ch "." ch
        $M(Win.Raw.Ascii) insert end $ch

        if { [incr M(Term.Count)] % 16 == 0 } {
            $M(Win.Raw.Hex) insert end \n
            $M(Win.Raw.Ascii) insert end \n
            ::moni::raw_insert_count
            ::moni::term_cutLines $M(Win.Raw.Hex) $M(Term.MaxLines)
            ::moni::term_cutLines $M(Win.Raw.Ascii) $M(Term.MaxLines)
        }
    }

    if { ! $M(Term.Hold) } {
        $M(Win.Raw.Hex) see end              ;# adjust view to text end
        $M(Win.Raw.Hex) mark set insert end  ;# set insertion cursor to text end
        $M(Win.Raw.Ascii) see end              ;# adjust view to text end
        $M(Win.Raw.Ascii) mark set insert end  ;# set insertion cursor to text end
    }
}

################## Clipboard action #########################
proc ::moni::copy_all {} {
    variable M

    # Find out which notebook page is visible
    # Get the complete contents of the text widget
    # Copy it to clipboard
    #
    set page [$M(Win.Notebook) raise]
    switch -- $page {
        tty     { set w $M(Win.TTY) }
        hex     { set w $M(Win.Raw.Hex) }
        default { return }
    }
    set txt [$w get 1.0 end-1c]
    if { [string length $txt] } {
        clipboard clear
        clipboard append $txt
    }
}
proc ::moni::selection_copy {} {
    if { [catch {selection get -selection PRIMARY} txt] } {
        set txt ""
    }
    if { [string length $txt] } {
        clipboard clear
        clipboard append $txt
    }
}
proc ::moni::selection_paste {} {
    if { [catch {selection get -selection CLIPBOARD} txt] } {
        set txt ""
    }
    if { [string length $txt] } {
        ::moni::rs232_put $txt
    }
}

################## Search action #########################
proc ::moni::search {} {
    variable M

    #
    # Find out which notebook page is visible
    #     1. Focus the text widget to display selection
    #     2. Setup the search pattern = selection
    #
    set page [$M(Win.Notebook) raise]
    switch -- $page {
        tty     { set txt $M(Win.TTY) }
        hex     { set txt $M(Win.Raw.Hex) }
        default { return }
    }
    focus $txt

    if { [catch {selection get -selection PRIMARY} pattern] } {
        set pattern ""  ;# no selection
    }
    #
    # If there is a selection in the text
    #     1. Setup the search pattern = selection
    #     2. Setup Search position = select position
    # otherwise
    #     1. Use the specified search pattern
    #     2. Start seraching from text begin
    #
    if {[string length $pattern]} {
        set M(Search.Pattern) $pattern
        set ranges [$txt tag ranges sel]
        set start [lindex $ranges 0]+1char
    } else {
        set start 1.0
    }
    set idx [$txt search -count count $M(Search.Pattern) $start end]
    #
    # If pattern is found
    #     1. Setup new selection
    #     2. Scroll text to found position
    #
    if {[string length $idx]} {
        $txt tag remove sel 1.0 end
        $txt tag add sel $idx "$idx + $count chars"
        $txt see $idx
    }
}
