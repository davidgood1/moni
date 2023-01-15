##################################################################
# Serial Port Monitor for Windows, Linux, Solaris
# (c) rs@rolf-schroedter.de http://www.rolf-schroedter.de/moni
##################################################################
# $Id: Moni.tcl 1503 2011-11-18 15:02:22Z schroedt $
##################################################################
#
# Features:
# - Monitors 1 serial port
# - Ascii & Hex display of incoming data
# - Ascii & Hex data output
# - Echo, File logging
# - Save & Load various configurations
#

package require Tk
wm withdraw .

set _SHOW_STARTUP 1

set _DIR(script)    [file dirname [info script]]
set _DIR(exe)       [file dirname [info nameofexecutable]]

if { [namespace exists ::starkit] } {
    if {[starkit::startup] eq "starkit"} {
        set _DIR(moni)  [file dirname $::starkit::topdir]
    } else {
        set _DIR(moni)  $_DIR(script)
    }
} else {
    set _DIR(moni)  $_DIR(script)
}
set _DIR(lib)       [file join $_DIR(script) library]
set _DIR(images)    [file join $_DIR(script) images]

lappend auto_path $_DIR(lib)

namespace eval ::moni {
    variable M

    set Setup(Wrap)     none
    set Setup(MaxLines) 1000
    set Setup(Ticker)   100

    set M(Version)          2.42
    set M(NeedTclVersion)   8.4
    set M(SetupFile)     [file join $_DIR(moni) moni.cfg]

    set M(Open)             0           ;# Is channel open
    set M(Chan)             {}          ;# The open channel

    set M(Config.Name)      ""          ;# Current configuration name (file)
    set M(Config.Dir)       $_DIR(moni) ;# Current configuration directory
    set M(Config.Changed)   0
    set M(Config.Id)        %Monitor-Configuration-File%
    set M(Config.FileTypes) { { "Config files" .cfg } { "All files" * } }

    set M(Log.Open)         0
    set M(Log.File)         {}          ;# Logfile channel
    set M(Log.Name)         "<none>"    ;# Logfile name
    set M(Log.Dir)          $_DIR(exe)  ;# Logfile directory
    set M(Log.FileTypes)    { { "Log files" .log } { "Text files" .txt } { "All files" * } }
    set M(Log.Count)        0           ;# Number of logged bytes

    set M(Send.FileName)    {}          ;# Filename to send via serial port
    set M(Send.Dir)			[pwd]       ;# Send file directory to remember
    set M(Send.FileSize)    0           ;# Size of file to send
    set M(Send.Data)        {}          ;# File contents
    set M(Send.Progress)    {}          ;# Progress status
    set M(Send.Repeat.Count)     1      ;# Repeat counter
    set M(Send.Repeat.Intervall) 1000   ;# Interval
    set M(Send.Delay)       0           ;# Milliseconds delay between sending two characters
    set M(Send.DelayCount)  0           ;# Number of character send with M(Send.Delay)
    set M(Send.Writing)     0           ;# Write operation pending

    set M(Status)           ""
    set M(Progress)         0
    set M(Plugins)          {}          ;# List of all loaded plugins

    set M(Term.MaxLines)    $Setup(MaxLines)    ;# 0: No terminal truncation, <>0: Truncate input
    set M(Term.Ticker)      $Setup(Ticker)  ;# Terminal: RS-232 status update interval
    set M(Term.Wrap)        $Setup(Wrap)    ;# Terminal: RS-232 status update interval

    set M(Term.Disconnect)  0           ;# 1: Disconnected; 0: Connected; Connection status: online/offline
    set M(Term.Stop)        0           ;# 1: Don't send data to terminal
    set M(Term.Hold)        0           ;# 1: Don't scroll terminal window after insert of incoming data
    set M(Term.Echo)        0           ;# 1: Echo input to terminal
    set M(Term.Log)         0           ;# 1: Log inoming data to file
    set M(Term.Count)       0           ;# Terminal: byte counter for text formatting
    set M(Term.TotalCount)  0           ;# Terminal: Total number of received bytes

    set M(TTY.OutQueue)     0           ;# TTY: Number of bytes in the output queue
    set M(TTY.InQueue)      0           ;# TTY: Number of bytes in the input queue
    set M(TTY.Led.Green)    ?           ;# Image for GREEN LED
    set M(TTY.Led.Red)      ?           ;# Image for RED LED

    set M(TTY.Stat.RTS)     0           ;# RTS output control
    set M(TTY.Stat.DTR)     0           ;# DTR output control
    set M(TTY.Stat.BREAK)   0           ;# BREAK output control
    set M(TTY.Stat.CTS)     0           ;# CTS input status
    set M(TTY.Stat.DSR)     0           ;# DSR input status
    set M(TTY.Stat.RING)    0           ;# Input status RING indicator
    set M(TTY.Stat.DCD)     0           ;# Input status CARRIER detect

    set M(TTY.CStat)        "offline"   ;# Connection status: online/offline

    set M(TTY.Errors)       0           ;# TTY: Error counter
    set M(TTY.LastError)    ""          ;# TTY: Last error

    set M(Win.TTY)          {}          ;# TTY-Terminal: text widget
    set M(Win.Raw.Hex)      {}          ;# Hex-Terminal: RAW text widget
    set M(Win.Raw.Ascii)    {}          ;# Hex-Terminal: ASCII text widget
    set M(Win.Raw.Input)    {}          ;# Hex-Terminal: hex input string
    set M(Win.Raw.Input.W)  {}          ;# Widget containg hex input string
    set M(Win.Notebook)     {}          ;# Notebook widget

    set M(Search.Pattern)   {}          ;# Search string

    set M(Font)             {}          ;# Selected font
    set M(Win.Font)         {}          ;# Font selector widget

    set M(Callback.input)   	{}      ;# List of callbacks for serial input
    set M(Callback.output)  	{}      ;# List of callbacks for serial output
}

#
# We need tcl >= 8.2 for working serial port fileevents
#
if { $tcl_version < $::moni::M(NeedTclVersion) } {
    tk_messageBox -type ok -icon error \
        -message "This program needs Tcl/Tk version $::moni::M(NeedTclVersion) or later\nThe current version is $tcl_version"
    exit
}
#
# make sure that we can load a DLL even if application is wrapped
#
if { [info exists tcl_platform(isWrapped)] } {
    rename load _load_original
    rename load_unsupported load
}

if { $_SHOW_STARTUP } {
    proc _startup_center { win } {
        wm withdraw $win    ;# don't show window
        update idletasks    ;# but determine window size

        set X [expr { ([winfo screenwidth  $win] - [winfo width  $win]) / 2 } ]
        set Y [expr { ([winfo screenheight $win] - [winfo height $win]) / 2 } ]

        wm deiconify $win
        wm geometry $win +$X+$Y
    }
    proc _startup_init {} {
        toplevel .startup -bd 2 -relief raised
        wm overrideredirect .startup 1
        label .startup.title -text "Serial Monitor $::moni::M(Version)"
        label .startup.status -width 40 -text [file tail [info script]]
        pack .startup.title .startup.status
        _startup_center .startup
        update
    }
    proc _startup_done {} {
        catch { destroy .startup }
        update
    }
    proc _startup_msg {msg} {
        .startup.status configure -text $msg
        update
    }
    _startup_init
}

catch {_startup_msg "Loading BWidgets ..."}
package require BWidget
catch {_startup_msg "Loading SerialConfig ..."}
package require SerialConfig
catch {_startup_msg "Init variables ..."}

catch {_startup_msg "Sourcing Monitor modules ..."}
source [file join $_DIR(script) Moni-Setup.tcl]
source [file join $_DIR(script) Moni-Config.tcl]
source [file join $_DIR(script) Moni-Win.tcl]
source [file join $_DIR(script) Moni-Term.tcl]
source [file join $_DIR(script) Moni-LogFile.tcl]
source [file join $_DIR(script) Moni-SendFile.tcl]
source [file join $_DIR(script) Moni-About.tcl]
source [file join $_DIR(script) Moni-Plugins.tcl]

proc ::moni::error_ret {msg} {
#    tk_messageBox -type ok -icon error -message $msg
    MessageDlg .error -type ok -icon error -message $msg
    return -code return
}

proc ::moni::init {} {
    variable M
    variable Cfg

    # default serial configuration
    #
    serialconfig::init

    set Cfg(Port)           [lindex $::serialconfig::ComPorts 0]
    set Cfg(Baud)           9600
    set Cfg(DataBits)       8
    set Cfg(StopBits)       1
    set Cfg(Parity)         none
    set Cfg(SysBuffer)      {4096 4096}
    set Cfg(Handshake)      none
    set Cfg(Pollinterval)   10


    # setup default font
    font create fn_fixed -family {Courier} -size 10 -weight normal -slant roman -underline 0 -overstrike 0
    option add *Text*font fn_fixed

    ::moni::win
    ::moni::win_title
    wm protocol . WM_DELETE_WINDOW { ::moni::done }

    ::moni::update_font fn_fixed

    BWidget::place . 0 0 center
    wm deiconify .
#    raise .
#    focus -force .

    ::moni::setup_load $M(SetupFile)
    ::moni::ticker
}
proc ::moni::done {} {
    variable M
    ::moni::setup_save
    if { [moni::config_close] } {
        exit
    }
}

proc ::moni::run {argc argv} {
    variable M

    set config 0; set connect 1		;# Default: Connect if configuration specified

    for {set i 0} {$i < $argc} { incr i} {
	set opt [lindex $argv $i]
	switch -- $opt {
	    -config {
		#
		# -config filename	-- Load configuration & connect by default
		#
		set fname [lindex $argv [incr i]]
		if {[file isfile $fname]} {
		    set M(Config.Dir)   [file dirname $fname]
		    set M(Config.Name)  [file tail $fname]
		    ::moni::config_load_file
		    set config 1
		}
	    }
	    -disconnect {
		#
		# -disconnect		-- Start configuration disconnected
		#
		set connect 0
	    }
	    default {
		#
		# Invalid option:	-- Display help
		#
		after idle [list moni::help [format "Invalid command-line option: %s" $opt]]
	    }
	}
    }
    if {$config} {
	if {$connect} {
	    ::moni::config_reopen
	} else {
	    set ::moni::M(Term.Disconnect) 1
	}
    }
}

catch {_startup_msg "Creating widgets ..."}
moni::init
update
catch {_startup_msg "Loading plugins ..."}
moni::load_plugins
catch {_startup_done}

moni::run $argc $argv

# testing:
# moni::run 3 [list -config "leon-sparc.cfg" -disconnect]

if 0 {
    console show
    parray ::moni::M
}
