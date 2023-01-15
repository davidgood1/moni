################################################################################
# run_script.tcl
# This source is free under the terms of the GPLv2 or later
# Created by: David Good
#
# This is a plugin for Moni, the serial port monitor written in TCL.  It allows
# the user to define automatic scripts for interacting with the serial port and
# serial port data.
################################################################################

namespace eval ::run_script {
    set rs(version)      0.0.1;          # Version number of this plugin
    set rs(file)         "";             # Script file to load and run
    set rs(text)         "";             # Full path of the output text widget
    # set rs(Data)         {}      ;        # File contents
    # set rs(Progress)     {}      ;        # Progress status
    # set rs(Sending)      0       ;        # Write operation pending
    # set rs(Hist_Enable)  1       ;        # Enable command history collection    
    # set rs(Next.Char)    0       ;        # Next char may be written
    # set rs(Next.String)  0       ;        # Next string may be written
    
    # set rs(Char.Delay)   0       ; # Delay between sending two characters
    # set rs(String.Delay) 0       ; # Delay between string repetitions 
    # set rs(String.Count) 1       ; # Repeat counter for sending string, 0=endless
    
    # set rs(String.Input) "foo bar"       ;# User input string to be interpreted
    # set rs(String.Data) ""               ;# Data string to be sent
    # set rs(String.EOL) ""		;# String end of line options
    # set rs(String.CS.enable)	0	;# Option to calculate and send a single byte
    #                                      #  checksum after the data
    # set rs(String.CS.value) 0	;# calculated checksum data as binary
    # set rs(String.CS.str) 0		;# calculated checksum data as string
    # set rs(String.CS.stx) 1		;# Include the first byte in checksum?
    # set rs(String.CS.etx) 1		;# Include the last byte in checksum?

    # set rs(Hist.File) "";                 # File name containing history data
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

# ------------------------------------------------------------------------------
# put_text
#
# Adds a string to the end of the text widget
# ------------------------------------------------------------------------------
proc ::run_script::put_text { str } {
    variable rs
    eval [list $rs(text) insert end $str]
    return $str
}

# ------------------------------------------------------------------------------
# Function to draw the main window
# ------------------------------------------------------------------------------
proc ::run_script::win { {win .rs} } {
    variable rs

    catch { destroy $win }
    toplevel $win -menu $win.menu
    wm title $win "Run Script - $rs(version)"

    # create the menu bar widget
    menu $win.menubar -type menubar
    $win.menubar add command -label "Load Script" \
        -command {::run_script::load_script}
    $win configure -menu $win.menubar

    text $win.text -wrap word -yscrollcommand "$win.scroll set"
    scrollbar $win.scroll -command "$win.text yview"
    set rs(text) "$win.text"
    # puts "\$rs(text) = $rs(text)"
    pack $win.scroll -side right -fill y
    pack $win.text -side left -fill both -expand 1
    put_text "Load a Script to begin\n"
    # set mf [MainFrame $win.frame]
    # pack $mf -fill both -expand yes

    # $mf addindicator -textvariable ::send_string::S(Progress) -width 20

    # set tf [TitleFrame $mf.tf_select_mode -text "Send String" \
    #             -side left -borderwidth 1]
    # pack $tf -side top -expand yes -fill both
    
    # set f [$tf getframe]

    # Label $f.t1 -text "String:" -anchor w  \
    #     -helptext "Output string to be sent."
    # Entry $f.et1 \
    #     -validate key -validatecommand [list ::send_string::process_str %P] \
    #     -textvariable ::send_string::S(String.Input) \
    #     -helptext [$f.t1 cget -helptext]

    # Label $f.t_hist -text "History:" -anchor w

    # checkbutton $f.c_hist_en -text "Enable" \
    #     -variable ::send_string::S(Hist_Enable)
    # DynamicHelp::register $f.c_hist_en balloon "Record sent strings to history list"
    
    # Button $f.b_hist_clear -text "Clear" -helptext "Clear the history window" -width 8 \
    #     -command {
    #         set f [.send_string.frame.tf_select_mode getframe]
    #         $f.lb_hist delete 0 end
    #     }

    # Button $f.b_hist_load -text "Load" -width 8 -helptext "Load a history" \
    #     -command {::send_string::load_history}

    # Button $f.b_hist_save -text "Save" -width 8 \
    #     -helptext "Save the current history" \
    #     -command {::send_string::save_history}


    # listbox $f.lb_hist -selectmode browse -height 6 \
    #     -yscrollcommand "$f.scrl_hist set" 
    # DynamicHelp::register $f.lb_hist \
    #     balloon "Click to send one of these strings"

    # scrollbar $f.scrl_hist -command "$f.lb_hist yview"
    
    # bind $f.et1 <FocusIn> {
    #     set f [.send_string.frame.tf_select_mode getframe]
    #     $f.lb_hist selection clear 0 end		
    # }

    # bind $f.lb_hist <<ListboxSelect>> {
    #     ::send_string::update_entry
    # }

    # bind $f.lb_hist <Button-1> {
    #     focus .send_string.frame.tf_select_mode.f.lb_hist
    # }

    # bind $win <Key-Return> {
    #     ::send_string::send_all
    # }

    # bind $win <Key-Delete> {
    #     set f [.send_string.frame.tf_select_mode getframe]
    #     set indx [$f.lb_hist curselection]
    #     if { $indx != "" } { $f.lb_hist delete $indx }
    # }

    #	bind $f.et1 <Key-Up> {
    #		set f [.send_string.frame.tf_select_mode getframe]
    #		set indx [$f.lb_hist curselection]
    #		if { $indx > 0 } {
    #			$f.lb_hist selection clear $indx
    #			incr indx -1
    #			$f.lb_hist selection set $indx
    #		}
    #	}
    
    #	bind $f.et1 <Key-Down> {
    #		set f [.send_string.frame.tf_select_mode getframe]
    #		set indx [$f.lb_hist curselection]
    #		if { $indx < [expr [$f.lb_hist size] - 1] } {
    #			$f.lb_hist selection clear $indx
    #			incr indx 1
    #			$f.lb_hist selection set $indx
    #		}
    #	}

#     frame $win.sep1 -height 2 -borderwidth 1 -relief sunken

    # grid $f.t1 -sticky news -pady 2
    # grid $f.et1 -row 0 -column 1 -sticky news -pady 2 -columnspan 3
    # grid $f.t_hist -row 1 -sticky nsew -pady 2
    # grid $f.c_hist_en -row 1 -column 1 -sticky wns
    # grid $f.b_hist_clear -row 1 -column 2 -sticky ens -columnspan 2
    # grid $f.lb_hist -row 2 -column 1 -sticky news -pady 2 -columnspan 2
    # grid $f.scrl_hist -row 2 -column 3 -sticky ns -pady 3
    # #    grid $f.b_hist_del_entry -row 3 -column 1 -sticky wns
    # grid $f.b_hist_load -row 3 -column 1 -sticky nse -padx 2
    # grid $f.b_hist_save -row 3 -column 2 -sticky ens -columnspan 2
    # grid columnconfigure $f 0 -weight 0
    # grid columnconfigure $f 1 -weight 1
    # grid columnconfigure $f 2 -weight 0
    # grid columnconfigure $f 3 -weight 0

#     set tf [TitleFrame $mf.tf_opt -text "Options" -side left -borderwidth 1]
#     pack $tf -side top -expand yes -fill x

#     set f [$tf getframe]
    
#     set f1 [frame $f.eol]
    
#     Label $f1.t1 -text "EOL: "   \
#         -helptext "Select end of line option"
    
#     radiobutton $f1.r1 -text "<none>" \
#         -variable ::send_string::S(String.EOL) -value ""
#     DynamicHelp::register $f1.r1 balloon "No end-of-line characters are sent"

#     radiobutton $f1.r2 -text "CRLF" \
#         -variable ::send_string::S(String.EOL) -value "\x0D\x0A"
#     DynamicHelp::register $f1.r2 balloon "DOS-style CR,LF are sent after each string"

#     radiobutton $f1.r3 -text "LF" \
#         -variable ::send_string::S(String.EOL) -value "\x0A"
#     DynamicHelp::register $f1.r3 balloon "UNIX-style LF is sent after each string"

#     radiobutton $f1.r4 -text "CR" \
#         -variable ::send_string::S(String.EOL) -value "\x0D"
#     DynamicHelp::register $f1.r4 balloon "CR is sent after each string"
    
#     pack $f1.t1 $f1.r1 $f1.r2 $f1.r3 $f1.r4 -side left -padx 2
#     pack $f1 -side top

#     set f2 [frame $f.cs]
#     Label $f2.tCS -text "CS: " \
#         -helptext "Select single byte checksum options"
    
#     checkbutton $f2.cCSenable -text "Enable" \
#         -variable ::send_string::S(String.CS.enable)
#     DynamicHelp::register $f2.cCSenable balloon "Send checksum after all data is sent"

#     checkbutton $f2.cCSstx -text "First Byte" \
#         -variable ::send_string::S(String.CS.stx)
#     DynamicHelp::register $f2.cCSstx balloon "Include first byte in checksum calculation"

#     checkbutton $f2.cCSetx -text "Last Byte" \
#         -variable ::send_string::S(String.CS.etx)
#     DynamicHelp::register $f2.cCSetx balloon "Include last byte in checksum calculation"

#     pack $f2.tCS $f2.cCSenable $f2.cCSstx $f2.cCSetx -side left -padx 2
#     pack $f2.tCS -side left
#     pack $f2 -side left

# #     pack $win.sep1 -fill x -pady 2


#     Label $f.t1 -text "Repeat: " -anchor w  \
#         -helptext "Repeat counter for sending the same string.\n(0= send forever)"
#     SpinBox $f.sb1 \
#         -textvariable ::send_string::S(String.Count) \
#         -width 8 -editable 1 -range {0 1000000 1} \
#         -helptext [$f.t1 cget -helptext]

#     Label $f.t2 -text "Char Delay: " -anchor w  \
#         -helptext "Delay between sending two characters in milliseconds\nWarning: Implemented as Tcl after delay, not very accurate."
#     SpinBox $f.sb2 \
#         -textvariable ::send_string::S(Char.Delay) \
#         -width 8 -editable 1 -range {0 10000 1} \
#         -helptext [$f.t2 cget -helptext]

#     Label $f.t3 -text "String Delay: " -anchor w  \
#         -helptext "Delay between string repetitions in milliseconds"
#     SpinBox $f.sb3 \
#         -textvariable ::send_string::S(String.Delay) \
#         -width 8 -editable 1 -range {0 3600000 100} \
#         -helptext [$f.t3 cget -helptext]

#     Button $f.send -text "Send" -helptext "Start sending the data string" \
#         -width 10 -command ::send_string::send_all
#     Button $f.stop -text "Stop" -helptext "Stop sending" \
#         -width 10 -command ::send_string::stop

#     grid $f.eol  -       -  -       -sticky news -pady 2
#     grid $f.cs   -       -  -       -sticky news -pady 2
#     grid $f.t1   $f.sb1  x  $f.send -sticky news -pady 2
#     grid $f.t2   $f.sb2  x  $f.stop -sticky news -pady 2
#     grid $f.t3   $f.sb3  x  $f.stop -sticky news -pady 2
#     grid columnconfigure $f 2 -weight 1 -minsize 10

}

# ------------------------------------------------------------------------------
# load_script dialog
# ------------------------------------------------------------------------------
proc ::run_script::load_script {} {
    variable rs

    set rs(file) [tk_getOpenFile -title "Load Script" \
                      -filetypes {{{TCL Files} {.tcl}} {{TCL Files} {}}}]

    if {$rs(file) != ""} {
        put_text "Selected File: $rs(file)\n"
        # tk_messageBox -icon info -message "Selected $rs(file)" -type ok \
        #     -title "Load Script"
        # # Open the file
        # set fid [open $S(Hist.File) r]

        # # populate listbox with file contents
        # set f [.send_string.frame.tf_select_mode getframe]
        # # f = .send_string.frame.tf_select_mode.f
        # $f.lb_hist delete 0 end;         # clear the list box
        # while {[gets $fid line] >= 0} {
        #     $f.lb_hist insert end $line
        # }
        # # Close the file
        # close $fid
    }
}

# ------------------------------------------------------------------------------
# Start actual execution here
# ------------------------------------------------------------------------------
# Add this item in moni plugins menu
set menu [.moni getmenu plugins]
$menu add command -label "Run Script" -command ::run_script::win

# Draw the window directly for now
# ::run_script::win

# ------------------------------------------------------------------------------
# End of File
# ------------------------------------------------------------------------------
