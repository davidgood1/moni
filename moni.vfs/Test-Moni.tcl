##################################################################
# Serial Port Monitor for Windows, Linux, Solaris
# (c) rs@rolf-schroedter.de http://www.rolf-schroedter.de/moni
##################################################################
# $Id: Test-Moni.tcl 1131 2008-02-02 17:13:01Z rolf $
##################################################################

set COM(Port)   com1
set COM(Mode)   "115200,n,8,1"

catch {console show; wm withdraw .}
puts "Tcl-Sender $tcl_patchLevel"
puts "test procedures using $COM(Port) at $COM(Mode)"
puts "    r    ?numBytes?"
puts "    w    ?string?"
puts "    sender"
puts "    fast ?kBytes=10?"

proc init {} {
    global COM
    set COM(Chan)   <none>
    set COM(Data)   "1234567890"
    set COM(Period) 1000
    set COM(Count)  0
    set COM(kByte)  "0123456789ABCDEF"

    for {set i 0} {$i < 6} {incr i} {
        append COM(kByte) $COM(kByte)
    }
    set COM(Chan) [open $COM(Port) r+]
    fconfigure $COM(Chan) -mode $COM(Mode) -buffering none -translation binary
}


proc r { args } {
    eval read $::COM(Chan) $args
}
proc w { {str ""} } {
    global COM
    if { $str == "" } {
        set str $COM(Data)
        puts stderr $str
    }
    puts -nonewline $COM(Chan) $str
}
proc sender {} {
    global COM
    incr COM(Count)
    w
    after [expr int($COM(Period)+1000.0*rand())] sender
}
proc fast { {kBytes 10} } {
    global COM

    set start [clock seconds]
    for {set i 0} {$i < $kBytes} {incr i} {
        puts -nonewline $COM(Chan) $COM(kByte)
    }
    set stop [clock seconds]
    set time [expr $stop - $start]
    incr time [expr $time == 0]
    if {$kBytes > $time} {
        set speed [expr 1.0*$kBytes/$time]
        puts stderr "$kBytes kB at [format "%1.1f" $speed] kB/sec"
    } else {
        set speed [expr 1024*$kBytes/$time]
        puts stderr "$kBytes kB at $speed byte/sec"
    }
}

init
