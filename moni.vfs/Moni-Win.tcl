##################################################################
# Serial Port Monitor for Windows, Linux, Solaris
# (c) rs@rolf-schroedter.de http://www.rolf-schroedter.de/moni
##################################################################
# $Id: Moni-Win.tcl 1472 2010-04-19 13:16:50Z schroedt $
##################################################################

namespace eval moni {
    variable M

    # Menu description
    set M(Menu) {
        "F&ile" all file 0 {
            {command "Send File"    {} "Send File"   {} -command ::moni::send_file}
            {separator}
            {command "Connect Por&t"    {} "Connect Port"   {} -command ::moni::connect}
            {command "Disconnect P&ort" {} "Disconnect Port"   {} -command ::moni::disconnect}
            {separator}
            {command "E&xit Monitor"    {} "Exit Monitor"   {} -command ::moni::done}
        }
        "E&dit" all edit 0 {
            {command "Copy"    {} "Copy selection to clipboard"   {} -command ::moni::selection_copy}
            {command "Copy all" {} "Copy all text to clipboard"   {} -command ::moni::copy_all}
            {command "Paste"   {} "Output data from clipboard"   {} -command ::moni::selection_paste}
            {separator}
            {command "Find"    {} "Find pattern"   {} -command ::moni::search}
            {separator}
            {command "Setup"   {} "Setup Moni"   {} -command ::moni::setup}
        }
        "S&erial" all serial 0 {
            {command "N&ew config"    {} "New config"         {} -command ::moni::config_new}
            {command "O&pen config"   {} "Open config"        {} -command ::moni::config_load}
            {command "S&ave config"   {} "Save config"        {} -command ::moni::config_save}
            {command "Save config as..." {} "Save config as ..." {} -command ::moni::config_save_as}
            {separator}
            {command "C&onfigure port" {} "Configure Port" {} -command ::moni::config_edit}
        }
        "L&ogfile" all logfile 0 {
            {command "N&ew logfile"     {} "New logfile"     {} -command ::moni::log_new}
            {command "A&ppend logfile"  {} "Append logfile"  {} -command ::moni::log_append}
            {separator}
            {command "C&lose logfile"   {} "Close logfile"   {} -command ::moni::log_close}
            {separator}
            {checkbutton "E&nable logging"  {all option} "Enable logging"   {} \
                -variable ::moni::M(Term.Log)
            }
        }
        "P&lugins" {all plugins} plugins 0 {
            {command "Show all..."   {} "Show all loaded plugins"   {} -command ::moni::show_plugins}
            {separator}
        }
        "   ?   " all help 0 {
            {command "Moni options"    {} "Moni help"       {} -command "moni::help"}
            {command "About Moni"      {} "About Moni"      {} -command "moni::about 0"}
            {command "About Tcl/Tk"    {} "About Tcl/Tk"    {} -command "moni::about 1"}
        }
    }
}

##################### Display a (toplevel) Window  centered above its parent ############################
proc ::moni::center_top { win } {
    tk::PlaceWindow $win "widget" [winfo toplevel [winfo parent $win]]
}

##################### TTY-Window ############################
proc ::moni::bitmap { name } {
    global _DIR
    Bitmap::get [file join $_DIR(images) $name]
}

##################### TTY-Window ############################
proc ::moni::win_tty { nb } {
    variable M

    set f [$nb insert end tty -text "TTY"]
    set sw  [ScrolledWindow $f.sw -scrollbar vertical -auto both]
    set txt [text $sw.txt -height 24 -width 80]
    $sw setwidget $txt
    pack $sw -fill both -expand yes

    set M(Win.TTY) $txt
    bind $M(Win.TTY) <Any-Key> { ::moni::tty_key %W %A %K }
}

##################### TTY-Status update $ OutputQueue ############################
proc ::moni::update_status {} {
    variable M

    if { $M(Open) } {
        set queueStr [fconfigure $M(Chan) -queue]
        set statStr  [fconfigure $M(Chan) -ttystatus]

        set M(TTY.InQueue)  [lindex $queueStr 0]
        set M(TTY.OutQueue) [lindex $queueStr 1]

        foreach {name val} $statStr {
	    set M(TTY.Stat.$name) $val
        }
    }
}
proc ::moni::tty_queue_changed {win args} {
    variable M
    if {$M(TTY.OutQueue)} {
        $win configure -bg yellow
    } else {
        $win configure -bg gray
    }
}
##################### TTY-Status LED's ############################
proc ::moni::tty_led_changed {win name idx op} {
    variable M

    if {$M($idx)} {
        $win configure -image $M(TTY.Led.Red)
    } else {
        $win configure -image $M(TTY.Led.Green)
    }
}
proc ::moni::tty_led_toggle {name} {
    variable M

    if { ! $M(Open) } {
        bell
        return
    }
    set val [expr {! $M(TTY.Stat.$name)}]
    fconfigure $M(Chan) -ttycontrol [list $name $val]
    set M(TTY.Stat.$name) $val
}
proc ::moni::win_tty_led { win name } {
    variable M

    frame $win
    label $win.txt -text "$name:"
    switch -exact -- $name {
        RTS - DTR - BREAK {
            button $win.led -image $M(TTY.Led.Green) -command [list ::moni::tty_led_toggle $name]
            DynamicHelp::register $win balloon "$name line (output)\nGreen=0, Red=1\nHit button to flip the line"
        }
        CTS - DSR - RING - DCD {
            label $win.led -image $M(TTY.Led.Green)
            DynamicHelp::register $win balloon "$name line (input)\nGreen=0, Red=1"
        }
    }
    trace variable M(TTY.Stat.$name) w [list ::moni::tty_led_changed $win.led]
    pack $win.txt $win.led -side left
}

##################### Hex-Window ############################
# 2 connected text widgets with 1 scrollbar for both
#
proc ::moni::win_hex_yview { frame args } {
    variable M
    eval $frame.hex yview $args
    eval $frame.ascii yview $args
}
proc ::moni::win_hex { nb } {
    variable M

    set f [$nb insert end hex -text "Hex"]

    set M(Win.Raw.Hex)   [text $f.hex -height 24 -width 58 -yscrollcommand "$f.sb set"]
    set M(Win.Raw.Ascii) [text $f.ascii -height 24 -width 16 -yscrollcommand "$f.sb set"]
    frame   $f.sep -width 2 ;# -bd 1 -relief solid
    scrollbar   $f.sb -orient vertical -command "::moni::win_hex_yview $f"

    grid $f.hex $f.sep $f.ascii $f.sb -sticky news
    grid rowconfigure $f 0 -weight 1
    grid columnconfigure $f 0 -weight 3
    grid columnconfigure $f 2 -weight 1

    bind $M(Win.Raw.Hex)   <Any-Key>   { ::moni::raw_key %W %A %K }
    bind $M(Win.Raw.Ascii) <Any-Key>   { ::moni::raw_key %W %A %K }

    ::moni::term_clear
}

##################### Toggled button  ####################
proc ::moni::toggle_button { var } {
    upvar $var flag
    set flag [expr ! $flag]
}
proc ::moni::flag_changed { bbox bidx name index op } {
    upvar $name x
    if { [info exists x($index)] } {    ;# is an arry
        set flag $x($index)
    } else {                    ;# is an array
        set flag $x
    }
    if { $flag } {
        $bbox itemconfigure $bidx -relief sunken
    } else {
        $bbox itemconfigure $bidx -relief raised
    }
}

##################### Connect/Disconnect  ####################
# open_close
#       Disconnect / connect serial line
#
proc ::moni::connect_disconnect {args} {
    variable M

    ::moni::toggle_button ::moni::M(Term.Disconnect)

    if {$M(Term.Disconnect)} { ;# ==> disconnect
        if { $M(Open) } {
            ::moni::close_chan 0
        } else {
            set M(Term.Disconnect) 0
        }
    } else { ;# ==> connect
        if { ! $M(Open) } {
            ::moni::config_open
        }
    }
}
proc ::moni::connect {} {
    variable M

    if {$M(Term.Disconnect)} {
        ::moni::connect_disconnect
    } else {
        ::moni::config_edit
    }
}
proc ::moni::disconnect {} {
    variable M

    if {! $M(Term.Disconnect)} {
        ::moni::connect_disconnect
    }
}

##################### Special log button  ####################
proc ::moni::log_changed { bbox bidx name index op } {
    upvar $name x
    variable M

    # if Logging is enabled and no file is open
    # ==> prompt for a file name
    #
    if { $M(Term.Log) && ! $M(Log.Open) } {
        ::moni::log_new
    }
    #
    # if Logging is disabled and file is open
    # ==> flush file buffer
    #
    if { ! $M(Term.Log) && $M(Log.Open) } {
        catch {flush $M(Log.File)}
    }
    #
    # No logging if no log file open
    #
    if { ! $M(Log.Open) } {
        set M(Term.Log) 0
    }
    ::moni::flag_changed $bbox $bidx ::moni::M Term.Log $op
}
##################### Config new font ############################
proc ::moni::update_font { newfont } {
    variable M

    . configure -cursor watch
    if { $newfont != $M(Font) } {
        $M(Win.Font) configure -font $newfont
        $M(Win.TTY)       configure -font $newfont
        $M(Win.Raw.Hex)   configure -font $newfont
        $M(Win.Raw.Ascii) configure -font $newfont
        set M(Font) $newfont
    }
    . configure -cursor ""
}

##################### Windows ############################
proc ::moni::win {} {
    variable M

    set mainframe [MainFrame .moni \
                       -menu         $M(Menu) \
                       -textvariable ::moni::M(Status) \
                       -progressvar  ::moni::M(Progress)]
    pack $mainframe -fill both -expand yes

    set f [$mainframe addindicator -textvariable ::moni::M(TTY.CStat) -width 5 -anchor w]
    DynamicHelp::register $f balloon "Connection status"

    set f [$mainframe addindicator -text "Errors:"]
    $f configure -relief flat
    DynamicHelp::register $f balloon "Show RS-232 errors"

    set f [$mainframe addindicator -textvariable ::moni::M(TTY.Errors) -width 5 -anchor w]
    DynamicHelp::register $f balloon "Total number of RS-232 errors"

    set f [$mainframe addindicator -textvariable ::moni::M(TTY.LastError) -width 16 -anchor w]
    DynamicHelp::register $f balloon "Last RS-232 error description"

    set f [$mainframe addindicator -text "Log:"]
    $f configure -relief flat
    DynamicHelp::register $f balloon "Logging of RS-232 input"

    set f [$mainframe addindicator -textvariable ::moni::M(Log.Name) -width 16 -anchor e]
    DynamicHelp::register $f balloon "Filename for RS232-input logging"

    set f [$mainframe addindicator -textvariable ::moni::M(Log.Count) -width 8 -anchor w]
    DynamicHelp::register $f balloon "Total number of bytes written to log-file"

    set f [$mainframe addindicator -text "Total:"]
    $f configure -relief flat
    DynamicHelp::register $f balloon "Total number of received bytes"

    set f [$mainframe addindicator -textvariable ::moni::M(Term.TotalCount) -width 8 -anchor w]
    DynamicHelp::register $f balloon "Total number of received bytes"

    set f [$mainframe addindicator -textvariable ::moni::M(Win.Raw.Input) -width 3]
    DynamicHelp::register $f balloon "Current hex byte to be sent to RS-232"
    $f configure -bg white
    set M(Win.Raw.Input.W) $f

    set f [$mainframe addindicator -text "Moni-$M(Version)"]
    $f configure -relief flat
    DynamicHelp::register $f balloon "Moni version number"

# toolbar 1 creation
    set tb1  [$mainframe addtoolbar]
    pack configure $tb1 -expand yes -fill x

    # left button bar
    set bbox [ButtonBox $tb1.bbox1 -spacing 0 -padx 1 -pady 1]

    $bbox add -image [Bitmap::get new] \
        -highlightthickness 0 -takefocus 0 -relief link -borderwidth 1 \
        -padx 1 -pady 1 -helptext "Create a new configuration" \
        -command ::moni::config_new
    $bbox add -image [Bitmap::get open] \
        -highlightthickness 0 -takefocus 0 -relief link -borderwidth 1 \
        -padx 1 -pady 1 -helptext "Open an existing configuration" \
        -command ::moni::config_load
    $bbox add -image [Bitmap::get save] \
        -highlightthickness 0 -takefocus 0 -relief link -borderwidth 1 \
        -padx 1 -pady 1 -helptext "Save configuration" \
        -command ::moni::config_save

    pack $bbox -side left -anchor w

    set sep [Separator $tb1.sep1 -orient vertical]
    pack $sep -side left -fill y -padx 4 -anchor w

    set bbox [ButtonBox $tb1.bbox2 -spacing 0 -padx 1 -pady 1]
    $bbox add -image [moni::bitmap prop] \
        -highlightthickness 0 -takefocus 0 -relief link -borderwidth 1 \
        -padx 1 -pady 1 -helptext "Serial port settings" \
        -command ::moni::config_edit

    pack $bbox -side left -anchor w

    set sep [Separator $tb1.sep2 -orient vertical]
    pack $sep -side left -fill y -padx 4 -anchor w

    set bbox [ButtonBox $tb1.bbox3 -spacing 0 -padx 1 -pady 1]
    $bbox add -image [moni::bitmap copy] \
        -highlightthickness 0 -takefocus 0 -relief link -borderwidth 1 \
        -padx 1 -pady 1 -helptext "Copy selection" \
        -command ::moni::selection_copy
    $bbox add -image [moni::bitmap paste] \
        -highlightthickness 0 -takefocus 0 -relief link -borderwidth 1 \
        -padx 1 -pady 1 -helptext "Paste selection" \
        -command ::moni::selection_paste

    pack $bbox -side left -anchor w

# right button bar
    set bbox [ButtonBox $tb1.bbox4 -spacing 2 -padx 0 -pady 0]

    $bbox add -image [moni::bitmap new] \
        -highlightthickness 0 -takefocus 0 -relief raised -borderwidth 1 \
        -padx 1 -pady 1 -width 20 -height 20 \
        -helptext "Clear window" \
        -command "::moni::term_clear"

    $bbox add -image [moni::bitmap sendfile] \
        -highlightthickness 0 -takefocus 0 -relief raised -borderwidth 1 \
        -padx 1 -pady 1 -width 20 -height 20 \
        -helptext "Send file to serial port" \
        -command "::moni::send_file"

    pack $bbox -side right -anchor e

    set sep [Separator $tb1.sep3 -orient vertical]
    pack $sep -side right -fill y -padx 4 -anchor w

# serach button and entry field
    set bbox [ButtonBox $tb1.bbox5 -spacing 2 -padx 0 -pady 0]

    $bbox add -image [moni::bitmap find] \
        -highlightthickness 0 -takefocus 0 -relief raised -borderwidth 1 \
        -padx 1 -pady 1 -width 20 -height 20 \
        -helptext "Find a pattern\n!!! Does not work over newlines !!!" \
        -command {::moni::search}

    set search [Entry $tb1.search -width 16 -textvariable ::moni::M(Search.Pattern)]
    $search configure -helptext "Enter search pattern here\nor select text to search"
    bind $search <Return> {::moni::search; break}

    pack $bbox $search -side right -anchor e -padx 1

# toolbar 2 creation
    set tb2 [$mainframe addtoolbar]
    pack configure $tb2 -expand yes -fill x

    catch {_startup_msg "Loading fonts ..."}
    set wf  [SelectFont $tb2.font -type toolbar \
                -command "moni::update_font \[$tb2.font cget -font\]"]
    set font [$wf cget -font]
    pack $wf -side left -anchor w
    set M(Win.Font) $wf

# right button bar
    set bbox [ButtonBox $tb2.bbox3 -spacing 2 -padx 0 -pady 0]

    $bbox add -image [moni::bitmap disconnect] \
        -highlightthickness 0 -takefocus 0 -relief raised -borderwidth 1 \
        -padx 1 -pady 1 -width 20 -height 20 \
        -helptext "Connect / disconnect" \
        -command "::moni::connect_disconnect"
    trace variable ::moni::M(Term.Disconnect) w "::moni::flag_changed $bbox 0"

    $bbox add -image [moni::bitmap disable] \
        -highlightthickness 0 -takefocus 0 -relief raised -borderwidth 1 \
        -padx 1 -pady 1 -width 20 -height 20 -helptext "Stop data display" \
        -command "::moni::toggle_button ::moni::M(Term.Stop)"
    trace variable ::moni::M(Term.Stop) w "::moni::flag_changed $bbox 1"

    $bbox add -image [moni::bitmap pin] \
        -highlightthickness 0 -takefocus 0 -relief raised -borderwidth 1 \
        -padx 1 -pady 1 -helptext "Hold data display" \
        -command "::moni::toggle_button ::moni::M(Term.Hold)"
    trace variable ::moni::M(Term.Hold) w "::moni::flag_changed $bbox 2"

    $bbox add -image [moni::bitmap speaker] \
        -highlightthickness 0 -takefocus 0 -relief raised -borderwidth 1 \
        -padx 1 -pady 1 -helptext "Terminal output echo" \
        -command "::moni::toggle_button ::moni::M(Term.Echo)"
    trace variable ::moni::M(Term.Echo) w "::moni::flag_changed $bbox 3"

    $bbox add -image [moni::bitmap logfile] \
        -highlightthickness 0 -takefocus 0 -relief raised -borderwidth 1 \
        -padx 1 -pady 1 -helptext "Switch file logging" \
        -command "::moni::toggle_button ::moni::M(Term.Log)"
    trace variable ::moni::M(Term.Log) w "::moni::log_changed $bbox 4"

    pack $bbox -side right -anchor e


# Main frame

    set mf [$mainframe getframe]

# Get LED images green/red
    set M(TTY.Led.Green) [moni::bitmap greenball]
    set M(TTY.Led.Red)   [moni::bitmap redball]

    set tty [frame $mf.tty]
    pack $tty -side bottom -fill x -pady 2

        set f [frame $tty.queue]
        pack $f -side right
        DynamicHelp::register $f balloon "Total number of queued output bytes"

            label $f.txt -text "Output queue:"
            label $f.val -textvariable ::moni::M(TTY.OutQueue) -width 6 -anchor w -relief sunken -bd 1
            trace variable ::moni::M(TTY.OutQueue) w [list ::moni::tty_queue_changed $f.val]

            pack $f.txt $f.val -side left -padx 4 -anchor w

    set sep [Separator $tty.sep1 -orient vertical]
        pack $sep -side right -fill y -padx 4

        set f [frame $tty.stat]
        pack $f -side right

            label $f.txt -text "Status lines:"
            DynamicHelp::register $f.txt balloon "Display RS-232 status lines (input)"
            trace variable ::moni::M(TTY.LineStatus) w ::moni::tty_status_changed

            moni::win_tty_led $f.cts  CTS
            moni::win_tty_led $f.dsr  DSR
            moni::win_tty_led $f.ring RING
            moni::win_tty_led $f.dcd  DCD

            pack $f.txt $f.cts $f.dsr $f.ring $f.dcd -side left -padx 4 -anchor w

    set sep [Separator $tty.sep2 -orient vertical]
        pack $sep -side right -fill y -padx 4

        set f [frame $tty.ctrl]
        pack $f -side right

            label $f.txt -text "Control lines:"
            DynamicHelp::register $f.txt balloon "RS-232 control lines (output)"

            moni::win_tty_led $f.rts  RTS
            moni::win_tty_led $f.dtr  DTR
            moni::win_tty_led $f.brk  BREAK

            pack $f.txt $f.rts $f.dtr $f.brk -side left -padx 4 -anchor w

catch {_startup_msg "notebook ..."}
# NoteBook creation
    set notebook [NoteBook $mf.nb]
    set M(Win.Notebook)  $notebook

    win_tty $notebook
    win_hex $notebook

    $notebook compute_size
    pack $notebook -fill both -expand yes -padx 4 -pady 4
    $notebook raise [$notebook page 0]
}

proc ::moni::win_title {} {
    variable M
    if { ! $M(Open) } {
        set name "<not connected>"
    } elseif { $M(Config.Name) == "" } {
        set name "<no name>"
    } else {
        set name $M(Config.Name)
    }
    if { $M(Config.Changed) } {
        set changed "*"
    } else {
        set changed ""
    }
    wm title . "Monitor $changed$name"
}
