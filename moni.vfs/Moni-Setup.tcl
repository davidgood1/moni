##################################################################
# Serial Port Monitor for Windows, Linux, Solaris
# (c) rs@rolf-schroedter.de http://www.rolf-schroedter.de/moni
##################################################################
# $Id: Moni-Setup.tcl 1146 2008-02-08 16:31:53Z rolf $
##################################################################
# Moni Setup widget
# - still rudimentary

proc ::moni::setup {} {
    set win .setup
    destroy $win
    toplevel $win
    wm title $win "Setup"

    ::moni::setup_restore

    set f [frame $win.entries]
    pack $f -side top

        Label $f.t1 -text "Max. Lines:" -width 10 -anchor w  \
            -helptext "Max. number of lines to hold in terminal window"
        ComboBox $f.c1 \
            -textvariable ::moni::Setup(MaxLines) -editable 1 \
            -values {100 1000 10000} \
            -helptext [$f.t1 cget -helptext]

        Label $f.t2 -text "Ticker:" -width 10 -anchor w  \
            -helptext "RS-232 status update interval\n(milliseconds)"
        ComboBox $f.c2 \
            -textvariable ::moni::Setup(Ticker) -editable 1 \
            -values {100 200 300 500 750 1000} \
            -helptext [$f.t2 cget -helptext]

        Label $f.t3 -text "Wrap mode:" -width 10 -anchor w  \
            -helptext "Select the desired text wrap mode"
        ComboBox $f.c3 \
            -textvariable ::moni::Setup(Wrap) -editable 0 \
            -values {none char word} \
            -helptext [$f.t3 cget -helptext]

        grid $f.t1 $f.c1 -pady 2
        grid $f.t2 $f.c2 -pady 2
        grid $f.t3 $f.c3 -pady 2

    set bbox [ButtonBox $win.bbox -spacing 10 -padx 1 -pady 1]
    $bbox add -text "Apply" -helptext "Apply changes" \
        -command "::moni::setup_apply; destroy $win" \
        -highlightthickness 0 -takefocus 0 -borderwidth 1 -padx 4 -pady 1
    $bbox add -text "Cancel" -helptext "Discard changes" \
        -command [list destroy $win] \
        -highlightthickness 0 -takefocus 0 -borderwidth 1 -padx 4 -pady 1
    pack $bbox -side bottom -anchor c -pady 4

#    raise $win
    ::moni::center_top $win
    focus -force $win
}

proc ::moni::setup_apply {} {
    variable Setup
    variable M

    set M(Term.MaxLines) $Setup(MaxLines)
    set M(Term.Ticker)   $Setup(Ticker)
    set M(Term.Wrap)     $Setup(Wrap)

    $M(Win.TTY) configure -wrap $Setup(Wrap)
    $M(Win.Raw.Hex) configure -wrap $Setup(Wrap)
    $M(Win.Raw.Ascii) configure -wrap $Setup(Wrap)
}
proc ::moni::setup_restore {} {
    variable Setup
    variable M

    set Setup(MaxLines) $M(Term.MaxLines)
    set Setup(Ticker)   $M(Term.Ticker)
    set Setup(Wrap)     $M(Term.Wrap)
}

proc ::moni::setup_save {} {
    variable Setup
    variable M

    ::moni::setup_restore

    set file [open $M(SetupFile) w]

    puts $file "# Serial Monitor setup file"
    foreach field [lsort -dictionary [array names Setup] ] {
        puts $file [ format "%-30s\t%s" "set Setup($field)" [list $Setup($field)] ]
    }
    close $file
}
proc ::moni::setup_load {filename} {
    variable Setup

    catch {source $filename}
    ::moni::setup_apply
}
