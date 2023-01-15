##################################################################
# Serial Port Monitor for Windows, Linux, Solaris
# (c) rs@rolf-schroedter.de http://www.rolf-schroedter.de/moni
##################################################################
# $Id: Moni-SendFile.tcl 1501 2011-07-11 12:37:35Z schroedt $
##################################################################

proc ::moni::select_send_file {} {
    variable M

    set filename [tk_getOpenFile -filetypes $M(Log.FileTypes)   \
                        -defaultextension .log                  \
                        -initialdir $M(Send.Dir)           		]
    if { $filename != "" } {
        if { [file exists $filename] && ! [file isfile $filename] } {
            ::moni::error_ret "File \"$filename\" is not a regular file"
        }
        set M(Send.Dir)		 [file dirname $filename]
        set M(Send.FileName) $filename
    }
}

proc ::moni::send_ready {} {
    variable M
    set M(Send.Writing) 0
    fileevent $M(Chan) writable {}
}
proc ::moni::send_data { {count 0} } {
    variable M

    # Sending with/without character delay
    #
    if { $M(Send.Delay) } {

        # Start write operation, character per character
        #
        foreach ch [split $M(Send.Data) {}] {
            ::moni::rs232_put $ch
            after $M(Send.Delay) {incr ::moni::M(Send.DelayCount)}
            tkwait variable ::moni::M(Send.DelayCount)
        }
    } else {

        # Start write operation, nonblocking in background
        #
        ::moni::rs232_put $M(Send.Data)
    }

    # Setup notifier for end of write operation
    # Wait until write operation finished
    # Remove notifier
    #
    set M(Send.Writing) 1
    fileevent $M(Chan) writable ::moni::send_ready
    tkwait variable ::moni::M(Send.Writing)

    incr count
    set M(Send.Progress) [format "%d/%d" $count $M(Send.Repeat.Count)]
    if { $count < $M(Send.Repeat.Count) } {
        after $M(Send.Repeat.Intervall) [list ::moni::send_data $count]
    }
}

proc ::moni::send_selected_file {} {
    variable M

    if { $M(Send.FileName) == "" } {
        ::moni::select_send_file
    }
    if { $M(Send.FileName) == "" } {
        return
    }
    if { ! $M(Open) } {
        ::moni::error_ret "Serial port not open"
    }
    if { $M(Send.Writing) } {
        return
    }
    set M(Send.FileSize) [file size $M(Send.FileName)]
    set chan [open $M(Send.FileName) r]
    fconfigure $chan -buffering none -translation binary
    set M(Send.Data) [read $chan $M(Send.FileSize)]
    close $chan

    ::moni::send_data
}

proc ::moni::send_file { {win .send_file} } {
    variable M

    catch { destroy $win }
    toplevel $win
    wm title $win "Send file"

    set mf [MainFrame $win.frame]
    pack $mf -fill both -expand yes

    $mf addindicator -textvariable ::moni::M(Send.Progress) -width 10

    set tf [TitleFrame $mf.file -text "Select file" -side left -borderwidth 1]
    pack $tf -side top -expand yes -fill both
    set f [$tf getframe]

        set le [LabelEntry $f.fname -label "Send file: " \
             -textvariable ::moni::M(Send.FileName) -width 40 \
             -helptext "Name of file to send to serial port"]
        pack $le -side left -expand yes -fill x

        set but [Button $f.browse -text "Browse" -helptext "Browse for file" \
            -command ::moni::select_send_file]
        pack $but -side left -padx 2 -pady 2

    set tf [TitleFrame $mf.repeat -text "Repeat" -side left -borderwidth 1]
    pack $tf -side top -expand yes -fill x
    set f [$tf getframe]

        set f1 [frame $f.f1]
        pack $f1 -side left

        Label $f1.t1 -text "Repeat counter: " -width 15 -anchor w  \
            -helptext "How many times the file contents should be sent"
        SpinBox $f1.sb1 \
            -textvariable ::moni::M(Send.Repeat.Count) \
            -width 8 -editable 1 -range {1 1000 1} \
            -helptext [$f1.t1 cget -helptext]

        Label $f1.t2 -text "Repeat interval: " -width 15 -anchor w  \
            -helptext "The delay between two file repetitions in milliseconds"
        SpinBox $f1.sb2 \
            -textvariable ::moni::M(Send.Repeat.Intervall) \
            -width 8 -editable 1 -range {0 1000000 100} \
            -helptext [$f1.t2 cget -helptext]

        Label $f1.t3 -text "Delay: " -width 15 -anchor w  \
            -helptext "Delay between sending two characters in milliseconds\nWarning: Implemented as Tcl after delay, not very accurate."
        SpinBox $f1.sb3 \
            -textvariable ::moni::M(Send.Delay) \
            -width 8 -editable 1 -range {0 10000 1} \
            -helptext [$f1.t2 cget -helptext]

        grid $f1.t1 $f1.sb1 -pady 2
        grid $f1.t2 $f1.sb2 -pady 2
        grid $f1.t3 $f1.sb3 -pady 2

#        Separator $f.sep -orient vertical
#        pack $f.sep -side left -padx 4 -fill y

        set but [Button $f.send -text "Send" -helptext "Send the file" \
                    -width 10 -command ::moni::send_selected_file]
        pack $but -side right -padx 2 -pady 2

    ::moni::center_top $win
}
