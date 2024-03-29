# -----------------------------------------------------------------------------
#  scrollw.tcl
#  This file is part of Unifix BWidget Toolkit
#  $Id: scrollw.tcl 1131 2008-02-02 17:13:01Z rolf $
# -----------------------------------------------------------------------------
#  Index of commands:
#     - ScrolledWindow::create
#     - ScrolledWindow::getframe
#     - ScrolledWindow::setwidget
#     - ScrolledWindow::configure
#     - ScrolledWindow::cget
#     - ScrolledWindow::_set_hframe
#     - ScrolledWindow::_set_vscroll
#     - ScrolledWindow::_setData
#     - ScrolledWindow::_setSBSize
#     - ScrolledWindow::_realize
# -----------------------------------------------------------------------------

namespace eval ScrolledWindow {
    Widget::declare ScrolledWindow {
	{-background  TkResource ""   0 button}
	{-scrollbar   Enum	 both 0 {none both vertical horizontal}}
	{-auto	      Enum	 both 0 {none both vertical horizontal}}
	{-sides	      Enum	 se   0 {ne en nw wn se es sw ws}}
	{-size	      Int	 0    1 "%d >= 0"}
	{-ipad	      Int	 1    1 "%d >= 0"}
	{-managed     Boolean	 1    1}
	{-relief      TkResource flat 0 frame}
	{-borderwidth TkResource 0    0 frame}
	{-bg	      Synonym	 -background}
	{-bd	      Synonym	 -borderwidth}
    }

    Widget::addmap ScrolledWindow "" :cmd {-relief {} -borderwidth {}}

    proc ::ScrolledWindow {path args} {
	return [eval [list ScrolledWindow::create $path] $args]
    }
    proc use {} {}
}


# -----------------------------------------------------------------------------
#  Command ScrolledWindow::create
# -----------------------------------------------------------------------------
proc ScrolledWindow::create { path args } {
    upvar \#0 ScrolledWindow::$path data

    Widget::init ScrolledWindow $path $args

    set bg     [Widget::cget $path -background]
    set sbsize [Widget::cget $path -size]
    set sw     [frame $path \
	    -relief flat -borderwidth 0 -background $bg \
	    -highlightthickness 0 -takefocus 0]

    scrollbar $path.hscroll \
	    -highlightthickness 0 -takefocus 0 \
	    -orient	 horiz	\
	    -relief	 sunken	\
	    -bg	 $bg
    scrollbar $path.vscroll \
	    -highlightthickness 0 -takefocus 0 \
	    -orient	 vert	\
	    -relief	 sunken	\
	    -bg	 $bg

    set data(realized) 0

    _setData $path \
	    [Widget::cget $path -scrollbar] \
	    [Widget::cget $path -auto] \
	    [Widget::cget $path -sides]

    if {[Widget::cget $path -managed]} {
	set data(hsb,packed) $data(hsb,present)
	set data(vsb,packed) $data(vsb,present)
    } else {
	set data(hsb,packed) 0
	set data(vsb,packed) 0
    }
    if {$sbsize} {
	$path.vscroll configure -width $sbsize
	$path.hscroll configure -width $sbsize
    } else {
	set sbsize [$path.vscroll cget -width]
    }
    set data(ipad) [Widget::cget $path -ipad]

    if {$data(hsb,packed)} {
	grid $path.hscroll -column 1 -row $data(hsb,row) \
		-sticky ew -ipady $data(ipad)
    }
    if {$data(vsb,packed)} {
	grid $path.vscroll -column $data(vsb,column) -row 1 \
		-sticky ns -ipadx $data(ipad)
    }

    grid columnconfigure $path 1 -weight 1
    grid rowconfigure	 $path 1 -weight 1

    bind $path <Configure> [list ScrolledWindow::_realize $path]
    bind $path <Destroy>   [list ScrolledWindow::_destroy $path]
    rename $path ::$path:cmd
    proc ::$path { cmd args } "return \[eval ScrolledWindow::\$cmd $path \$args\]"

    return $path
}


# -----------------------------------------------------------------------------
#  Command ScrolledWindow::getframe
# -----------------------------------------------------------------------------
proc ScrolledWindow::getframe { path } {
    return $path
}


# -----------------------------------------------------------------------------
#  Command ScrolledWindow::setwidget
# -----------------------------------------------------------------------------
proc ScrolledWindow::setwidget { path widget } {
    upvar \#0 ScrolledWindow::$path data

    grid $widget -in $path -row 1 -column 1 -sticky news

    $path.hscroll configure -command [list $widget xview]
    $path.vscroll configure -command [list $widget yview]
    $widget configure \
	    -xscrollcommand [list ScrolledWindow::_set_hscroll $path] \
	    -yscrollcommand [list ScrolledWindow::_set_vscroll $path]
}


# -----------------------------------------------------------------------------
#  Command ScrolledWindow::configure
# -----------------------------------------------------------------------------
proc ScrolledWindow::configure { path args } {
    upvar \#0 ScrolledWindow::$path data

    set res [Widget::configure $path $args]
    if { [Widget::hasChanged $path -background bg] } {
	$path configure -background $bg
	catch {$path.hscroll configure -background $bg}
	catch {$path.vscroll configure -background $bg}
    }

    if {[Widget::hasChanged $path -scrollbar scrollbar] | \
	    [Widget::hasChanged $path -auto	 auto]	| \
	    [Widget::hasChanged $path -sides	 sides]} {
	_setData $path $scrollbar $auto $sides
	foreach {vmin vmax} [$path.hscroll get] { break }
	set data(hsb,packed) [expr {$data(hsb,present) && \
		(!$data(hsb,auto) || ($vmin != 0 || $vmax != 1))}]
	foreach {vmin vmax} [$path.vscroll get] { break }
	set data(vsb,packed) [expr {$data(vsb,present) && \
		(!$data(vsb,auto) || ($vmin != 0 || $vmax != 1))}]

	set data(ipad) [Widget::cget $path -ipad]

	if {$data(hsb,packed)} {
	    grid $path.hscroll -column 1 -row $data(hsb,row) \
		    -sticky ew -ipady $data(ipad)
	}
	if {$data(vsb,packed)} {
	    grid $path.vscroll -column $data(vsb,column) -row 1 \
		    -sticky ns -ipadx $data(ipad)
	}
    }
    return $res
}


# -----------------------------------------------------------------------------
#  Command ScrolledWindow::cget
# -----------------------------------------------------------------------------
proc ScrolledWindow::cget { path option } {
    return [Widget::cget $path $option]
}


# -----------------------------------------------------------------------------
#  Command ScrolledWindow::_destroy
# -----------------------------------------------------------------------------
proc ScrolledWindow::_destroy { path } {
    upvar \#0 ScrolledWindow::$path data

    unset data
    Widget::destroy $path
    rename $path {}
}


# -----------------------------------------------------------------------------
#  Command ScrolledWindow::_set_hscroll
# -----------------------------------------------------------------------------
proc ScrolledWindow::_set_hscroll { path vmin vmax } {
    upvar \#0 ScrolledWindow::$path data

    if {$data(realized) && $data(hsb,present)} {
	if {$data(hsb,auto)} {
	    if {$data(hsb,packed) && $vmin == 0 && $vmax == 1} {
		if {![info exists data(hlock)]} {
		    set data(hsb,packed) 0
		    grid remove $path.hscroll
		}
	    } elseif {!$data(hsb,packed) && ($vmin != 0 || $vmax != 1)} {
		set data(hsb,packed) 1
		grid $path.hscroll -column 1 -row $data(hsb,row) \
			-sticky ew -ipady $data(ipad)
		set data(hlock) 1
		update idletasks
		unset data(hlock)
	    }
	}
	$path.hscroll set $vmin $vmax
    }
}


# -----------------------------------------------------------------------------
#  Command ScrolledWindow::_set_vscroll
# -----------------------------------------------------------------------------
proc ScrolledWindow::_set_vscroll { path vmin vmax } {
    upvar \#0 ScrolledWindow::$path data

    if {$data(realized) && $data(vsb,present)} {
	if {$data(vsb,auto)} {
	    if {$data(vsb,packed) && $vmin == 0 && $vmax == 1} {
		if {![info exists data(vlock)]} {
		    set data(vsb,packed) 0
		    grid remove $path.vscroll
		}
	    } elseif {!$data(vsb,packed) && ($vmin != 0 || $vmax != 1) } {
		set data(vsb,packed) 1
		grid $path.vscroll -column $data(vsb,column) -row 1 \
			-sticky ns -ipadx $data(ipad)
		set data(vlock) 1
		update idletasks
		unset data(vlock)
	    }
	}
	$path.vscroll set $vmin $vmax
    }
}


proc ScrolledWindow::_setData {path scrollbar auto sides} {
    upvar \#0 ScrolledWindow::$path data

    set sb    [lsearch {none horizontal vertical both} $scrollbar]
    set auto  [lsearch {none horizontal vertical both} $auto]

    set data(hsb,present)  [expr {($sb & 1) != 0}]
    set data(hsb,auto)	   [expr {($auto & 1) != 0}]
    set data(hsb,row)	   [expr {[string match *n* $sides] ? 0 : 2}]

    set data(vsb,present)  [expr {($sb & 2) != 0}]
    set data(vsb,auto)	   [expr {($auto & 2) != 0}]
    set data(vsb,column)   [expr {[string match *w* $sides] ? 0 : 2}]
}

# -----------------------------------------------------------------------------
#  Command ScrolledWindow::_realize
# -----------------------------------------------------------------------------
proc ScrolledWindow::_realize { path } {
    upvar \#0 ScrolledWindow::$path data

    bind $path <Configure> {}
    set data(realized) 1
}
