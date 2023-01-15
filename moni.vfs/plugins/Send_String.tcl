##################################################################
# Send_String.tcl
# This source is free under the terms of the GPL
# Created by: Rolf Schroedter
# Modified by: David Good
##################################################################

namespace eval ::send_string {
    set S(Version)      0.0.4   ;# Version number of this plugin
    set S(Data)         {}      ;# File contents
    set S(Progress)     {}      ;# Progress status
    set S(Sending)      0       ;# Write operation pending
    set S(Hist_Enable)  1       ;# Enable command history collection
    set S(Next.Char)    0       ;# Next char may be written
    set S(Next.String)  0       ;# Next string may be written

    set S(Char.Delay)   0       ;# Delay between sending two characters
    set S(String.Delay) 0       ;# Delay between string repetitions
    set S(String.Count) 1       ;# Repeat counter for sending string, 0=endless

    set S(String.Input) "foo bar"       ;# User input string to be interpreted
    set S(String.Data) ""               ;# Data string to be sent
    set S(String.EOL) ""		;# String end of line options
    set S(String.CS.enable)	0	;# Option to calculate and send a single byte
                                         #  checksum after the data
    set S(String.CS.value) 0	        ;# calculated checksum data as binary
    set S(String.CS.stx) 1		;# Include the first byte in checksum?
    set S(String.CS.etx) 1		;# Include the last byte in checksum?

    set S(Hist.File) "";                 # File name containing history data
}

proc ::send_string::send_string { data } {
    variable S

    # Sending a string with/without character delay
    #
    if { $::send_string::S(Char.Delay) } {

        # Start write operation, character per character
        #
        foreach ch [split $data {}] {
            ::moni::rs232_put $ch
            after $S(Char.Delay) {incr ::send_string::S(Next.Char)}
            tkwait variable ::send_string::S(Next.Char)

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
        fileevent $::moni::M(Chan) writable {incr ::send_string::S(Next.Char)}
        tkwait variable ::send_string::S(Next.Char)
        fileevent $::moni::M(Chan) writable {}
    }
}

proc ::send_string::send_all {} {
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

    # Format the send command with optional CS
    #
    if {$S(String.CS.enable) == 1} {
        set cmd [list ::send_string::send_string $S(String.Data)$S(String.CS.value)$S(String.EOL)]
    } else {
        set cmd [list ::send_string::send_string $S(String.Data)$S(String.EOL)]
    }

    # Send the same string with optional repetition
    #
    set S(Sending)  1
    set i 0
    while { ($S(String.Count) == 0) || ($i < $S(String.Count))} {
        eval $cmd

        if {! $S(Sending)} return   ;# return if stopped

        after $S(String.Delay) {incr ::send_string::S(Next.String)}
        tkwait variable ::send_string::S(Next.String)

        if {! $S(Sending)} return   ;# return if stopped

        incr i

        # Update the status bar
        set S(Progress) "CS: [bin_str $S(String.CS.value)]  "
        append S(Progress) [format "Sent: %d / %d" $i $S(String.Count)]
    }
    ::send_string::stop
}

proc ::send_string::stop {} {
    variable S

    # Stop sending
    # Send signals to pending background processes
    #
    set S(Sending)     0        ;# Stop sending
    set S(Next.Char)   1        ;# Signal end of S(Char.Delay)
    set S(Next.String) 1        ;# Signal end of S(String.Delay)

    # Add string to history listbox
    set f [.send_string.frame.tfSendString getframe]
    if { $S(Hist_Enable) } {
      set found 0
      foreach item [ $f.lb_hist get 0 end ] {
        if { $item == $S(String.Input) } { set found 1 }
      }
      if { $found != 1 } {
        $f.lb_hist insert 0 $S(String.Input)
      }
    }
}

proc ::send_string::process_str { in_str } {
    variable S

    #
    # Check string for escaped hex char or backslashed char
    #
    set in_str [string map {\[ \\[ \] \\] \$ \\$ \\ \\\\} $in_str]
    regsub -all {\\\\([0-9A-Fa-f]{2})} $in_str {[binary format H2 \1]} in_str
    set S(String.Data) [subst $in_str]

    #
    # Calculate new CS
    #
    set tmp 0
    if { $S(String.CS.stx) == 0 } {
        set n 1
    } else {
        set n 0
    }
    set count [string length $S(String.Data)]
    if { $S(String.CS.etx) == 0 } {
	set count [expr $count - 1]
    }
    for {} {$n < $count} {incr n} {
        binary scan [string index $S(String.Data) $n] c ctmp
        set tmp [expr $tmp ^ $ctmp]
    }
    set S(String.CS.value) [binary format c $tmp]

    #
    # Update display
    #
    set S(Progress) "CS: [bin_str $S(String.CS.value)]"

    return 1
}

# ------------------------------------------------------------------------------
# bin_str
#
# Formats a string into it's byte values separated by spaces
# (e.g. 30 31 32 33 etc...)
# ------------------------------------------------------------------------------
proc bin_str { str } {
    set tmp_str ""
    foreach ch [split $str ""] {
        binary scan $ch "H2" tmp_ch
        append tmp_str [string toupper $tmp_ch] " "
    }
    return [string trim $tmp_str]
}

#
# Create the Send-String window
#
proc ::send_string::win { {win .send_string} } {
    variable S

    catch { destroy $win }
    toplevel $win
    wm title $win "Send String - $S(Version)"

    set mf [MainFrame $win.frame]
    pack $mf -fill both -expand 1
    pack forget $mf.topf
    $mf addindicator -textvariable ::send_string::S(Progress) -width 20

    # SendString Frame
    set tf [TitleFrame $mf.tfSendString -text "Send String" \
                -side left -borderwidth 1]
    pack $tf -side top -expand 1 -fill both

    set f [$tf getframe]

    Label $f.t1 -text "String:" -anchor w  \
        -helptext "Output string to be sent."
    Entry $f.et1 \
        -validate key -validatecommand [list ::send_string::process_str %P] \
        -textvariable ::send_string::S(String.Input) \
        -helptext [$f.t1 cget -helptext]

    Label $f.t_hist -text "History:" -anchor nw

    checkbutton $f.c_hist_en -text "Enable" \
        -variable ::send_string::S(Hist_Enable)
    DynamicHelp::register $f.c_hist_en balloon "Record sent strings to history list"

    Button $f.b_hist_clear -text "Clear" -helptext "Clear the history window" -width 8 \
        -command {
            set f [.send_string.frame.tfSendString getframe]
            $f.lb_hist delete 0 end
        }

    Button $f.b_hist_load -text "Load" -width 8 -helptext "Load a history" \
        -command {::send_string::load_history}

    Button $f.b_hist_save -text "Save" -width 8 \
        -helptext "Save the current history" \
        -command {::send_string::save_history}


    listbox $f.lb_hist -selectmode browse -height 6 \
        -yscrollcommand "$f.scrl_hist set"
    DynamicHelp::register $f.lb_hist \
        balloon "Click to send one of these strings"

    scrollbar $f.scrl_hist -command "$f.lb_hist yview"

    bind $f.et1 <FocusIn> {
        set f [.send_string.frame.tfSendString getframe]
        $f.lb_hist selection clear 0 end
    }

    bind $f.lb_hist <<ListboxSelect>> {
        ::send_string::update_entry
    }

    bind $f.lb_hist <Button-1> {
        focus .send_string.frame.tfSendString.f.lb_hist
    }

    bind $win <Key-Return> {
        ::send_string::send_all
    }

    bind $win <Key-Delete> {
        set f [.send_string.frame.tfSendString getframe]
        set indx [$f.lb_hist curselection]
        if { $indx != "" } { $f.lb_hist delete $indx }
    }

    #	bind $f.et1 <Key-Up> {
    #		set f [.send_string.frame.tfSendString getframe]
    #		set indx [$f.lb_hist curselection]
    #		if { $indx > 0 } {
    #			$f.lb_hist selection clear $indx
    #			incr indx -1
    #			$f.lb_hist selection set $indx
    #		}
    #	}

    #	bind $f.et1 <Key-Down> {
    #		set f [.send_string.frame.tfSendString getframe]
    #		set indx [$f.lb_hist curselection]
    #		if { $indx < [expr [$f.lb_hist size] - 1] } {
    #			$f.lb_hist selection clear $indx
    #			incr indx 1
    #			$f.lb_hist selection set $indx
    #		}
    #	}

#     frame $win.sep1 -height 2 -borderwidth 1 -relief sunken

    grid $f.t1 -sticky news -pady 2
    grid $f.et1 -row 0 -column 1 -sticky news -pady 2 -columnspan 3
    grid $f.t_hist -row 1 -sticky nsew -pady 2
    grid $f.c_hist_en -row 1 -column 1 -sticky wns
    grid $f.b_hist_clear -row 1 -column 2 -sticky ens -columnspan 2
    grid $f.lb_hist -row 2 -column 1 -sticky news -pady 2 -columnspan 2
    grid $f.scrl_hist -row 2 -column 3 -sticky ns -pady 3
    grid $f.b_hist_load -row 3 -column 1 -sticky nse -padx 2
    grid $f.b_hist_save -row 3 -column 2 -sticky ens -columnspan 2
    grid columnconfigure $f 0 -weight 0
    grid columnconfigure $f 1 -weight 1
    grid columnconfigure $f 2 -weight 0
    grid columnconfigure $f 3 -weight 0
    grid rowconfigure    $f 2 -weight 1

    # Options Frame
    set tf [TitleFrame $mf.tfOpt -text "Options" -side left -borderwidth 1]
    pack $tf -side top -fill x
    set f [$tf getframe]

    # EOL Subframe
    set f1 [frame $f.eol]

    Label $f1.t1 -text "EOL: "   \
        -helptext "Select end of line option"

    radiobutton $f1.r1 -text "<none>" \
        -variable ::send_string::S(String.EOL) -value ""
    DynamicHelp::register $f1.r1 balloon "No end-of-line characters are sent"

    radiobutton $f1.r2 -text "CRLF" \
        -variable ::send_string::S(String.EOL) -value "\x0D\x0A"
    DynamicHelp::register $f1.r2 balloon "DOS-style CR,LF are sent after each string"

    radiobutton $f1.r3 -text "LF" \
        -variable ::send_string::S(String.EOL) -value "\x0A"
    DynamicHelp::register $f1.r3 balloon "UNIX-style LF is sent after each string"

    radiobutton $f1.r4 -text "CR" \
        -variable ::send_string::S(String.EOL) -value "\x0D"
    DynamicHelp::register $f1.r4 balloon "CR is sent after each string"

    pack $f1.t1 $f1.r1 $f1.r2 $f1.r3 $f1.r4 -side left -padx 2


    # Checksum Subframe
    set f2 [frame $f.cs]

    Label $f2.tCS -text "CS: " \
        -helptext "Select single byte checksum options"

    checkbutton $f2.cCSenable -text "Enable" \
        -variable ::send_string::S(String.CS.enable) \
        -command {::send_string::process_str $::send_string::S(String.Input)}
    DynamicHelp::register $f2.cCSenable balloon "Send checksum after all data is sent"

    checkbutton $f2.cCSstx -text "First Byte" \
        -variable ::send_string::S(String.CS.stx) \
        -command {::send_string::process_str $::send_string::S(String.Input)}
    DynamicHelp::register $f2.cCSstx balloon "Include first byte in checksum calculation"

    checkbutton $f2.cCSetx -text "Last Byte" \
        -variable ::send_string::S(String.CS.etx) \
        -command {::send_string::process_str $::send_string::S(String.Input)}
    DynamicHelp::register $f2.cCSetx balloon "Include last byte in checksum calculation"

    pack $f2.tCS $f2.cCSenable $f2.cCSstx $f2.cCSetx -side left -padx 2
    pack $f2.tCS -side left


    # Send Subframe
    set f3 [frame $f.send]

    Label $f3.t1 -text "Repeat: " -anchor w  \
        -helptext "Repeat counter for sending the same string.\n(0= send forever)"
    SpinBox $f3.sb1 \
        -textvariable ::send_string::S(String.Count) \
        -width 8 -editable 1 -range {0 1000000 1} \
        -helptext [$f3.t1 cget -helptext]

    Label $f3.t2 -text "Char Delay: " -anchor w  \
        -helptext "Delay between sending two characters in milliseconds\nWarning: Implemented as Tcl after delay, not very accurate."
    SpinBox $f3.sb2 \
        -textvariable ::send_string::S(Char.Delay) \
        -width 8 -editable 1 -range {0 10000 1} \
        -helptext [$f3.t2 cget -helptext]

    Label $f3.t3 -text "String Delay: " -anchor w  \
        -helptext "Delay between string repetitions in milliseconds"
    SpinBox $f3.sb3 \
        -textvariable ::send_string::S(String.Delay) \
        -width 8 -editable 1 -range {0 3600000 100} \
        -helptext [$f3.t3 cget -helptext]

    Button $f3.send -text "Send" -helptext "Start sending the data string" \
        -width 10 -command ::send_string::send_all
    Button $f3.stop -text "Stop" -helptext "Stop sending" \
        -width 10 -command ::send_string::stop

    # grid $f.eol  -       -  -       -sticky news -pady 2
    # grid $f.cs   -       -  -       -sticky news -pady 2
    grid $f3.t1   $f3.sb1  x  $f3.send -sticky news -pady 2
    grid $f3.t2   $f3.sb2  x  $f3.stop -sticky news -pady 2
    grid $f3.t3   $f3.sb3  x  $f3.stop -sticky news -pady 2
    grid columnconfigure $f3 2 -weight 1 -minsize 10

    # Pack all of the Option Subframes
    pack $f1 -expand yes -fill x
    pack $f2 -expand yes -fill x
    pack $f3 -expand yes -fill x
    # pack $f1 -side top
    # pack $f2 -side left
}

#
# Procedure to keep the entry widget updated with the history box selection
#
proc ::send_string::update_entry {} {
	set f [.send_string.frame.tfSendString getframe]
	set indx [$f.lb_hist curselection]
	if {$indx != ""} {
		$f.et1 delete 0 end
		$f.et1 insert end [$f.lb_hist get $indx]
#		$f.lb_hist selection clear 0 end
	}
}

# ------------------------------------------------------------------------------
# save_history dialog
# ------------------------------------------------------------------------------
proc ::send_string::save_history {} {
    variable S

    set ftypes {
        {{HST Files} {.hst}}
        {{HST Files} {}}
    }

    set S(Hist.File) [tk_getSaveFile -title "Save History As" \
                          -filetypes $ftypes]
    if {$S(Hist.File) != ""} {
        # Add the file extension if it is missing
        if {[regexp {.+?\.[Hh][Ss][Tt]} $S(Hist.File) tmp]} {
            lappend $S(Hist.File) ".hst"
        }

        # Open the file
        set fid [open $S(Hist.File) w]

        # Write out each listbox entry to the file
        set f [.send_string.frame.tfSendString getframe]
        # f = .send_string.frame.tfSendString.f
        foreach item [ $f.lb_hist get 0 end ] {
            puts $fid $item
        }
        # Close the file
        close $fid
    }
}

# ------------------------------------------------------------------------------
# load_history dialog
# ------------------------------------------------------------------------------
proc ::send_string::load_history {} {
    variable S

    set ftypes {
        {{HST Files} {.hst}}
        {{HST Files} {}}
    }

    set S(Hist.File) [tk_getOpenFile -title "Load History File" \
                          -filetypes $ftypes]
    if {$S(Hist.File) != ""} {
        # Open the file
        set fid [open $S(Hist.File) r]

        # populate listbox with file contents
        set f [.send_string.frame.tfSendString getframe]
        # f = .send_string.frame.tfSendString.f
        $f.lb_hist delete 0 end;         # clear the list box
        while {[gets $fid line] >= 0} {
            $f.lb_hist insert end $line
        }
        # Close the file
        close $fid
    }
}

#
# Add an entry to Plugins menu
#
proc ::send_string::init {} {
    set menu [.moni getmenu plugins]
    $menu add command -label "Send String" -command ::send_string::win
	::send_string::win
}

::send_string::init
