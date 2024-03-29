# ------------------------------------------------------------------------------
#  labelentry.tcl
#  This file is part of Unifix BWidget Toolkit
#  $Id: labelentry.tcl 1131 2008-02-02 17:13:01Z rolf $
# ------------------------------------------------------------------------------
#  Index of commands:
#     - LabelEntry::create
#     - LabelEntry::configure
#     - LabelEntry::cget
#     - LabelEntry::bind
# ------------------------------------------------------------------------------

namespace eval LabelEntry {
    Entry::use
    LabelFrame::use

    Widget::bwinclude LabelEntry LabelFrame .labf \
        remove {-relief -borderwidth -focus} \
        rename {-text -label} \
        prefix {label -justify -width -anchor -height -font -textvariable}

    Widget::bwinclude LabelEntry Entry .e \
        remove {-fg -bg} \
        rename {-foreground -entryfg -background -entrybg}

    Widget::addmap LabelEntry "" :cmd {-background {}}

    Widget::syncoptions LabelEntry Entry .e {-text {}}
    Widget::syncoptions LabelEntry LabelFrame .labf {-label -text -underline {}}

    ::bind BwLabelEntry <FocusIn> {focus %W.labf}
    ::bind BwLabelEntry <Destroy> {Widget::destroy %W; rename %W {}}

    proc ::LabelEntry { path args } { return [eval LabelEntry::create $path $args] }
    proc use { } {}
}


# ------------------------------------------------------------------------------
#  Command LabelEntry::create
# ------------------------------------------------------------------------------
proc LabelEntry::create { path args } {
    array set maps [list LabelEntry {} :cmd {} .labf {} .e {}]
    array set maps [Widget::parseArgs LabelEntry $args]

    eval frame $path $maps(:cmd) -class LabelEntry \
	    -relief flat -bd 0 -highlightthickness 0 -takefocus 0
    Widget::initFromODB LabelEntry $path $maps(LabelEntry)
	
    set labf  [eval LabelFrame::create $path.labf $maps(.labf) \
                   -relief flat -borderwidth 0 -focus $path.e]
    set subf  [LabelFrame::getframe $labf]
    set entry [eval Entry::create $path.e $maps(.e)]

    pack $entry -in $subf -fill both -expand yes
    pack $labf  -fill both -expand yes

    bindtags $path [list $path BwLabelEntry [winfo toplevel $path] all]

    rename $path ::$path:cmd
    proc ::$path { cmd args } "return \[LabelEntry::_path_command $path \$cmd \$args\]"

    return $path
}


# ------------------------------------------------------------------------------
#  Command LabelEntry::configure
# ------------------------------------------------------------------------------
proc LabelEntry::configure { path args } {
    return [Widget::configure $path $args]
}


# ------------------------------------------------------------------------------
#  Command LabelEntry::cget
# ------------------------------------------------------------------------------
proc LabelEntry::cget { path option } {
    return [Widget::cget $path $option]
}


# ------------------------------------------------------------------------------
#  Command LabelEntry::bind
# ------------------------------------------------------------------------------
proc LabelEntry::bind { path args } {
    return [eval ::bind $path.e $args]
}


#------------------------------------------------------------------------------
#  Command LabelEntry::_path_command
#------------------------------------------------------------------------------
proc LabelEntry::_path_command { path cmd larg } {
    if { ![string compare $cmd "configure"] ||
         ![string compare $cmd "cget"] ||
         ![string compare $cmd "bind"] } {
        return [eval LabelEntry::$cmd $path $larg]
    } else {
        return [eval $path.e:cmd $cmd $larg]
    }
}
