##################################################################
# Serial Port Monitor for Windows, Linux, Solaris
# (c) rs@rolf-schroedter.de http://www.rolf-schroedter.de/moni
##################################################################
# $Id: Moni-LogFile.tcl 1131 2008-02-02 17:13:01Z rolf $
##################################################################

proc ::moni::log_open { filename mode } {
    variable M

    if { [file exists $filename] && ! [file isfile $filename] } {
        ::moni::error_ret "File \"$filename\" is not a regular file"
    }
    set M(Log.Dir)  [file dirname $filename]
    set M(Log.Name) [file tail $filename]
    set M(Log.File) [open $filename $mode]
    fconfigure $M(Log.File) -translation binary
    set M(Log.Open) 1
    set M(Term.Log) 1
    set M(Log.Count) 0
}
proc ::moni::log_close {} {
    variable M

    if { $M(Log.Open) } {
        catch {close $M(Log.File)}
        set M(Log.Open) 0
        set M(Term.Log) 0
    }
}

proc ::moni::log_new {} {
    variable M

    if { $M(Log.Open) } {
        ::moni::log_close
    }
    set filename [tk_getSaveFile -filetypes $M(Log.FileTypes)    \
                        -defaultextension .log                   \
                        -initialdir $M(Log.Dir)                  ]
    if { $filename != "" } {
        ::moni::log_open $filename w
    }
}

proc ::moni::log_append {} {
    variable M

    if { $M(Log.Open) } {
        ::moni::log_close
    }
    set filename [tk_getOpenFile -filetypes $M(Log.FileTypes)    \
                        -defaultextension .log                   \
                        -initialdir $M(Log.Dir)                  ]
    if { $filename != "" } {
        ::moni::log_open $filename a
    }
}
proc ::moni::log_out { str } {
    variable M

    if { $M(Log.Open) } {
        incr M(Log.Count) [string length $str]
        puts -nonewline $M(Log.File) $str
    }
}