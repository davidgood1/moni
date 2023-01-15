##################################################################
# Serial Port Monitor for Windows, Linux, Solaris
# (c) rs@rolf-schroedter.de http://www.rolf-schroedter.de/moni
##################################################################
# $Id: Moni-About.tcl 1146 2008-02-08 16:31:53Z rolf $
##################################################################
# About window

namespace eval ::moni {
    variable M
    variable _about

    set tcl [format "Tcl %s" $::tcl_patchLevel]
    set bwidget [format "BWidget %s" [package versions BWidget]]

    set _about(Monitor) "Moni version $M(Version) \n\
                        A simple serial port monitor \n\n\
                        (c) Rolf Schrödter \n\
                        Tongrubenweg 106 \n\
                        D-12559 Berlin, Germany \n\n\
                        rs@rolf-schroedter.de"
    set _about(TclTk)   "$tcl / $bwidget\n\n\
                        Tcl/Tk is a powerful, platform \n\
                        independent scripting language \n\n\
                        For more information see: \n\
                        \t http://wiki.tcl.tk \n\
                        \t news:comp.lang.tcl"
    set _about(Help) "Moni $M(Version) command-line options:\n\n\
                        -config filename\n\
                        \tLoad serial port config & connect by default\n\
                        -disconnect\n\
                        \tStart Moni disconnected"
}
proc ::moni::about { {TclTk 0} } {
    variable M
    variable _about

    set win .about
    catch {destroy $win}
    toplevel $win
    wm title $win "About"

    if { $TclTk } {
        set w [ label $win.img -image [moni::bitmap pwrdLogo150] ]
    } else {
        set w [ label $win.img -image [moni::bitmap moni_icon128] ]
        DynamicHelp::register $w balloon "This program is dedicated to\n our sweet \"Moni\" (1995-1999)"
    }
    pack $w -side left -anchor nw

    set f [frame $win.button]
    pack $f -side bottom -pady 10
        set w [ button $f.ok -text "OK" -width 8 -command "destroy $win" ]
        pack $w -side right -padx 10
        if { $TclTk } {
            set msg $_about(TclTk)
        } else {
            set msg $_about(Monitor)
        }

    set w [ label $win.msg -justify left -text $msg ]
    pack $w -side left

    ::moni::center_top $win
    tkwait window $win
}
proc ::moni::help { {msg ""} } {
    variable M
    variable _about

    set win .about
    catch {destroy $win}
    toplevel $win
    wm title $win "Moni help"

    set w [ label $win.img -image [moni::bitmap moni_icon128] ]
    DynamicHelp::register $w balloon "This program is dedicated to\n our sweet \"Moni\" (1995-1999)"
    pack $w -side left -anchor nw

    set f [frame $win.button]
    pack $f -side bottom -pady 10
        set w [ button $f.ok -text "OK" -width 8 -command "destroy $win" ]
        pack $w -side right -padx 10

    if { $msg != "" } {
	append msg \n\n$_about(Help)
    } else {
	set msg $_about(Help)
    }

    set w [ label $win.msg -justify left -text $msg ]
    pack $w -side left

    ::moni::center_top $win
    tkwait window $win
}
