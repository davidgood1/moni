##################################################################
# Serial Port Monitor for Windows, Linux, Solaris
# (c) rs@rolf-schroedter.de http://www.rolf-schroedter.de/moni
##################################################################
# $Id: SerialConfig.tcl 1503 2011-11-18 15:02:22Z schroedt $
##################################################################

package provide SerialConfig 2.0

package require BWidget

#
# ComPorts		-- List of available serial ports (initialized in get_serial_ports)
# HandshakeModes	--  List of all Handshake modes (some of them are platform dependent)
# BaudRates
#
namespace eval serialconfig {		;# Create an empty namespace
    variable ComPorts		{}
    variable HandshakeModes	{none xonxoff rtscts}
    variable BaudRates		{110 300 1200 2400 4800 9600 19200 38400 57600 115200}
}

# ::serialconfig::get_serial_ports_from_win_registry
#	- Retrieve avalable com-ports from Windows registry
#
# parameters:
#
#       none
# returns:
#       none	-- Global variables ComPorts, HandshakeModes are updated
#
# Thanks to Rüdiger Härtel <r_haertel@gmx.de> proposing to retrieve ComPorts from Windows registry
# Note: This procedure may fail on modern PC's, if there is no COM port registered.
#
proc serialconfig::get_serial_ports_from_win_registry {} {
    #
    # Get available com-ports from windows registry
    #
    package require registry
    set serial_base "HKEY_LOCAL_MACHINE\\HARDWARE\\DEVICEMAP\\SERIALCOMM"

    set values [ registry values $serial_base ]

    set ComPorts {}
    foreach valueName $values {
	set port [string trim [registry get $serial_base $valueName]]
	set com "\\\\.\\$port"
	lappend ComPorts $com
    }
    lsort $ComPorts
}

# ::serialconfig::get_serial_ports
#	- Retrieve avalable com-ports from Operating System
#
# parameters:
#       none
# returns:
#       none	-- Global variables ComPorts, HandshakeModes are updated
#
proc serialconfig::get_serial_ports {} {

    variable ComPorts
    variable HandshakeModes {none xonxoff rtscts}

    switch -glob -- $::tcl_platform(os) {
        Linux* {
            set ComPorts [lsort [glob /dev/tty{USB,GS,S,ACM}*]]
            # set ComPorts {/dev/ttyS0 /dev/ttyS1 /dev/ttyS2 /dev/ttyS3}
        }
        SunOS* {
            set ComPorts {/dev/ttya /dev/ttyb}
        }
        Windows* {

	    #
	    # Get available com-ports from windows registry
	    # If this fails, then use COM1..4
	    #
	    set err [catch {get_serial_ports_from_win_registry} ComPorts]
	    if { $err } {
		set ComPorts {COM1 COM2 COM3 COM4}
	    }

	    #
	    # Windows supports an additional DTRDSR handshake option
	    #
	    lappend HandshakeModes dtrdsr
        }
        default {
            error "Unsupported OS"
        }
    }
    #
    # Error if there are no available com-ports seen
    #
    if { [llength $ComPorts] == 0 } {
	error "No serial ports available"
    }
}

# ::serialconfig::win
# parameters:
#       win     The toplevel window
#       title   The window title
#       var     The array-variable with serial config
#               Fields: Port Baud DataBits StopBits Parity Timeout
# returns:
#       boolean 1=array has be changed, 0=configuration canceled
#
proc serialconfig::win { win title var } {
    upvar $var Cfg
    variable Apply 0

    variable ComPorts
    variable HandshakeModes
    variable BaudRates

    # Destroy an eventually existing configuration widget
    #
    catch { destroy $win }
    toplevel $win
    wm title $win $title

    # Update the currently available ports from the OS.
    # E.g. there might be a new USB-to-Serial port plugged-in.
    #
    get_serial_ports

    # Edit a Copy of current configuration
    # just to be able to cancle editing.
    #
    catch {unset Edit}
    variable Edit
    array set Edit [array get Cfg]

    # Create the configuration widget
    #
    set f [frame $win.cfg]

        Label $f.t1 -text "Com port:" -width 15 -anchor w  \
            -helptext "Select the com port"
        ComboBox $f.c1 \
            -textvariable ::serialconfig::Edit(Port) -editable 1 \
            -values $ComPorts \
            -helptext [$f.t1 cget -helptext]

        Label $f.t2 -text "Baud rate:" -width 15 -anchor w  \
            -helptext "Select the desired baud rate"
        ComboBox $f.c2 \
            -textvariable ::serialconfig::Edit(Baud) -editable 1 \
            -values $BaudRates \
            -helptext [$f.t2 cget -helptext]

        Label $f.t3 -text "Data bits:" -width 15 -anchor w  \
            -helptext "Select the number of stop bits"
        ComboBox $f.c3 \
            -textvariable ::serialconfig::Edit(DataBits) -editable 0 \
            -values {8 7 6 5 4} \
            -helptext [$f.t3 cget -helptext]

        Label $f.t4 -text "Stop bits:" -width 15 -anchor w  \
            -helptext "Select the number of stop bits"
        ComboBox $f.c4 \
            -textvariable ::serialconfig::Edit(StopBits) -editable 0 \
            -values {1 1.5 2} \
            -helptext [$f.t4 cget -helptext]

        Label $f.t5 -text "Parity:" -width 15 -anchor w  \
            -helptext "Select the parity"
        ComboBox $f.c5 \
            -textvariable ::serialconfig::Edit(Parity) -editable 0 \
            -values {none even odd space} \
            -helptext [$f.t5 cget -helptext]

        Label $f.t6 -text "Handshake:" -width 15 -anchor w  \
            -helptext "Select the handshake mode"
        ComboBox $f.c6 \
            -textvariable ::serialconfig::Edit(Handshake) -editable 0 \
            -values $HandshakeModes \
            -helptext [$f.t6 cget -helptext]

        set boxes 6

    switch -glob -- $::tcl_platform(os) {
        Windows* {
            Label $f.t7 -text "System buffer:" -width 15 -anchor w  \
                -helptext "Windows system buffer size for Read and Write"
            ComboBox $f.c7 \
                -textvariable ::serialconfig::Edit(SysBuffer) -editable 1 \
                -values {"4096 4096" "16384 4096" "32768 4096" "65536 4096" } \
                -helptext [$f.t7 cget -helptext]

            Label $f.t8 -text "Poll interval:" -width 15 -anchor w  \
                -helptext "Tcl event polling intervall for this port"
            ComboBox $f.c8 \
                -textvariable ::serialconfig::Edit(Pollinterval) -editable 1 \
                -values {10 30 100} \
                -helptext [$f.t8 cget -helptext]

            set boxes 8
        }
    }

    for {set i 1} {$i <= $boxes} {incr i} {
        grid $f.t$i $f.c$i -pady 2
    }

    pack $f -side top

    set bbox [ButtonBox $win.bbox -spacing 10 -padx 1 -pady 1]
    $bbox add -text Apply -helptext "Apply changes" \
        -command {set serialconfig::Apply 1} \
        -highlightthickness 0 -takefocus 0 -borderwidth 1 -padx 4 -pady 1
    $bbox add -text Cancel -helptext "Discard changes" \
        -command {set ::serialconfig::Apply 0} \
        -highlightthickness 0 -takefocus 0 -borderwidth 1 -padx 4 -pady 1
    pack $bbox -side bottom -anchor c -pady 4

    wm protocol $win WM_DELETE_WINDOW {set serialconfig::Apply 0}
#    raise $win
    #
    # Display the window centered on top its parent
    #
    tk::PlaceWindow $win "widget" [winfo toplevel [winfo parent $win]]
    focus -force $win

    tkwait variable ::serialconfig::Apply
    if { $Apply } {
        array set Cfg [array get Edit]
    }
    catch {destroy $win}
    return $Apply
}

# ::serialconfig::init
#
# parameters:
#       none
# returns:
#       none
#
proc serialconfig::init {} {
    #
    # Initially retrieve serial port information
    #
    get_serial_ports
}
