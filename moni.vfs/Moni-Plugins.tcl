##################################################################
# Serial Port Monitor for Windows, Linux, Solaris
# (c) rs@rolf-schroedter.de http://www.rolf-schroedter.de/moni
##################################################################
# $Id: Moni-Plugins.tcl 1472 2010-04-19 13:16:50Z schroedt $
##################################################################
# Simple plugin loader
##################################################################

#
# Register Input, output and status change callbacks
#    type - The callback type: input / output / status
#
proc ::moni::callback {type command} {
    variable M

    if { ! [info exists M(Callback.$type)] } {
	error [format "Invalid callback type =%s" $type]
    }
    lappend M(Callback.$type) $command
}

#
# Execute Input, output and status change callbacks
#    type - The callback type: input / output / status
#
proc ::moni::exec_callbacks {type args} {
    variable M

    if { ! [info exists M(Callback.$type)] } {
	error [format "Invalid callback type =%s" $type]
    }
    foreach cmd $M(Callback.$type) {
	foreach arg $args {
	    lappend cmd $arg
	}
	uplevel #0 $cmd
    }
}

#
# Load moni plugins
# - Plugins may be located from two directories:
#   1. A "plugins" folder inside the moni-kit
#   2. A "plugins" folder in the moni executable directory
# - All files "*.tcl" in the plugin folder are sourced in alphabetical
# - Avoid to load from the same directory twice
#
proc ::moni::load_plugin_dir {dir} {
    variable M

    if {[file isdirectory $dir]} {
        set scripts [glob -nocomplain [file join $dir *.tcl]]
        foreach script [lsort -dictionary $scripts] {
            lappend M(Plugins) $script
            uplevel #0 [list source $script]
        }
    }
}
proc ::moni::load_plugins {} {
    variable M

    ::moni::load_plugin_dir [file join $::_DIR(script) plugins]
    if {! [string equal $::_DIR(moni) $::_DIR(script)] } {
        ::moni::load_plugin_dir [file join $::_DIR(moni) plugins]
    }
    if {[llength $M(Plugins)]} {
        .moni setmenustate plugins normal
    } else {
        .moni setmenustate plugins disabled
    }
}

proc ::moni::show_plugins {} {
    variable M
    variable _about

    set win .plugins
    catch {destroy $win}
    toplevel $win
    wm title $win "Moni plugins"

    set txt [text $win.txt]

    set x 10
    set y 1
    foreach plugin $M(Plugins) {
        $txt insert end $plugin\n
        incr y
        set len [string length $plugin]
        set x [expr {($len+1 > $x) ? $len+1 : $x}]
    }
    $txt configure -width $x -height $y
    pack $txt -side top -expand yes -fill both

    ::moni::center_top $win
    tkwait window $win
}