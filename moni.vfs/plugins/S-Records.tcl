##################################################################
# Serial Port Monitor for Windows, Linux, Solaris
# (c) rs@rolf-schroedter.de http://www.rolf-schroedter.de/moni
##################################################################
# $Id: S-Records.tcl 1502 2011-07-11 12:38:30Z schroedt $
##################################################################
# S-Record loader plugin
# - Moni2.30 adds rudimentary support for user-plugins.
# - This file may be used as a sample plugin.
# - It's recommended to create an own namespace to avoid conflicts
#   with future versions of Moni.
# - For adding menu entries its recommended to use the "plugins"
#   menuid.
##################################################################

namespace eval ::srec {
    set S(Dir)  	   [pwd]
    set S(FileTypes)   { { "Binary files" {.bin .out .img} } { "All files" * } }
    set S(FileName)    {}          ;# Filename to send via serial port
    set S(FileSize)    0           ;# Size of file to send
    set S(Data)        {}          ;# File contents
    set S(Progress)    {}          ;# Progress status
    set S(Writing)     0           ;# Write operation pending
    set S(WriteNext)   0           ;# Next record may be written

    set S(AddrSize)    16          ;# Default 16-bit addresses
    set S(Addr)        0000        ;# 26/24/32-bit hex address value
    set S(AddrX)       0           ;# Same address value als integer number
    set S(Length)      1           ;# Data size to dump

    set S(PacketSize)  16          ;# max. number of bytes per S-record
    set S(DataIndex)   0           ;# Data index during background write
}

#
# Hex address validation for 16/24/32-bit addresses (4/6/8 digits)
#
proc ::srec::validate_address {str} {
    variable S
    expr {[string is xdigit $str] && [string len $str] <= $S(AddrSize)/4}
}

#
# Address size changed to 16/24/32-bit.
# Trim address to have exactly 4/6/8 hex digits.
#
proc ::srec::address_size {} {
    variable S

    set len  [expr {$S(AddrSize)/4}]
    set S(Addr) [string range $S(Addr) end-[expr {$len-1}] end]
    set S(Addr) [format %0${len}s $S(Addr) ]
}

proc ::srec::select_send_file {} {
    variable S

    set filename [tk_getOpenFile -filetypes $S(FileTypes)   \
                        -defaultextension .log              \
                        -initialdir $S(Dir)                 ]
    if { $filename != "" } {
        if { [file exists $filename] && ! [file isfile $filename] } {
            ::srec::error_ret "File \"$filename\" is not a regular file"
        }
        set S(Dir) 		[file dirname $filename]
        set S(FileName) $filename
    }
}

# Create an S-Record of a given type=0-9
# with a given address and binary data
#
proc ::srec::create { type addr {data {}} } {

    # Create the address: 16/24/32-bit
    #
    switch -exact -- $type {
        S0 - S1 - S5 - S9 - SA { ;# 16-bit address
            set addr [expr {$addr & 0xFFFF}]
            set rec [format "%04X" $addr]
            set sum [expr {($addr & 0xFF) + (($addr & 0xFF00) >> 8)}]
        }
        S2 - S8 - SB { ;# 24-bit address
            set addr [expr {$addr & 0xFFFFFF}]
            set rec [format "%06X" $addr]
            set sum [expr {($addr & 0xFF) + (($addr & 0xFF00) >> 8) + (($addr & 0xFF0000) >> 16)}]
        }
        S3 - S7 - SC { ;# 32-bit address
            set addr [expr {$addr & 0xFFFFFFFF}]
            set rec [format "%08X" $addr]
            set sum [expr {($addr & 0xFF) + (($addr & 0xFF00) >> 8) + (($addr & 0xFF0000) >> 16) + (($addr & 0xFF000000) >> 24)}]
        }
        default {
            error "S-Records: unsupported S-Records type 'S$type'"
        }
    }

    # Append the data bytes
    #
    binary scan $data c* bytes
    foreach x $bytes {
        set x [expr {$x & 0xFF}]
        append rec [format "%02X" $x]
        incr sum $x
    }

    # Calculate the counter field
    #
    set len   [string length $rec]
    set count [expr {(($len+2)/2) & 0xFF}]
    incr sum $count

    # Calculate the checksum = one's complement of sum over (count,address,data)
    #
    set sum [expr {($sum ^ 0xFF) & 0xFF}]

    # Format the S-Record = 'Sx',count,addr,data,checksum
    #
    set rec [format "%s%02X%s%02X" $type $count $rec $sum]
}

proc ::srec::put { data } {

    # Sending with/without character delay
    #
    if { $::moni::M(Send.Delay) } {

        # Start write operation, character per character
        #
        foreach ch [split $data {}] {
            ::moni::rs232_put $ch
            after $::moni::M(Send.Delay) {incr ::srec::S(WriteNext)}
            tkwait variable ::srec::S(WriteNext)
        }
    } else {

        # Start write operation, nonblocking in background
        #
        ::moni::rs232_put $data

        # Setup notifier for end of write operation
        # Wait until write operation finished
        # Remove notifier
        #
        fileevent $::moni::M(Chan) writable {incr ::srec::S(WriteNext)}
        tkwait variable ::srec::S(WriteNext)
        fileevent $::moni::M(Chan) writable {}
    }
}

proc ::srec::send_nextdata {} {
    variable S

    # Start write operation, nonblocking in background
    #
    set size [string length $S(Data)]
    set toWrite [expr {$size - $S(DataIndex)}]
    if {$toWrite > 0} {
        #
        # Send next data packet
        #
        set toWrite [expr {($toWrite > $S(PacketSize)) ? $S(PacketSize) : $toWrite}]
        set addr    [expr {$S(AddrX)+$S(DataIndex)}]

        binary scan $S(Data) @${S(DataIndex)}a${toWrite} data

        switch -exact -- $S(AddrSize) {
            16 {set rec [srec::create S1 $addr $data]}
            24 {set rec [srec::create S2 $addr $data]}
            32 {set rec [srec::create S3 $addr $data]}
        }
        ::srec::put $rec\n

        #
        # Update progress indicator
        #
        incr S(DataIndex) $toWrite
        set S(Progress) [format "%d/%d" $S(DataIndex) $size]

        return
    }
    #
    # Optionally write Execute S-record
    #
    if {$S(Execute) && ! [info exists S(ExecuteWritten)]} {
        switch -exact -- $S(AddrSize) {
            16 {set rec [srec::create S9 $S(AddrX)]}
            24 {set rec [srec::create S8 $S(AddrX)]}
            32 {set rec [srec::create S7 $S(AddrX)]}
        }
        ::srec::put $rec\n

        set S(ExecuteWritten) 1
        return
    }
    #
    # Ready sending data
    #
    catch {unset S(ExecuteWritten)}
    set S(Writing) 0
}
proc ::srec::send_data {} {
    variable S

    # Send filename as "S0...." record
    # Reset data index for background write
    #
    set S(AddrX)     [expr 0x$S(Addr)]
    set S(DataIndex) 0
    set S(Writing)   1
    ::srec::put [srec::create S0 0 [file tail $S(FileName)]]\n

    while {$S(Writing)} {
        ::srec::send_nextdata
    }
}

# Upload a binary file as S-Records
#
proc ::srec::send_file {} {
    variable S

    if { $S(FileName) == "" } {
        ::srec::select_send_file
    }
    if { $S(FileName) == "" } {
        return
    }
    if { ! $::moni::M(Open) } {
        ::moni::error_ret "Serial port not open"
    }
    if { $S(Writing) } {
        return
    }
    set S(FileSize) [file size $S(FileName)]
    set chan [open $S(FileName) r]
    fconfigure $chan -buffering none -translation binary
    set S(Data) [read $chan $S(FileSize)]
    close $chan

    ::srec::send_data
}

# Dump target data as S-Records
#
proc ::srec::dump_nextdata {} {
    variable S

    # Start write operation, nonblocking in background
    #
    set toWrite [expr {$S(Length) - $S(DataIndex)}]
    if {$toWrite > 0} {
        #
        # Send next data packet
        #
        set toWrite [expr {($toWrite > $S(PacketSize)) ? $S(PacketSize) : $toWrite}]
        set addr    [expr {$S(AddrX)+$S(DataIndex)}]

        set len [binary format c1 $toWrite]

        switch -exact -- $S(AddrSize) {
            16 {set rec [srec::create SA $addr $len]}
            24 {set rec [srec::create SB $addr $len]}
            32 {set rec [srec::create SC $addr $len]}
        }
        ::srec::put $rec\n

        #
        # Update progress indicator
        #
        incr S(DataIndex) $toWrite
        set S(Progress) [format "%d/%d" $S(DataIndex) $S(Length)]

        return
    }
    #
    # Ready sending data
    #
    set S(Writing) 0
}
proc ::srec::dump_data {} {
    variable S

    if { ! $::moni::M(Open) } {
        ::moni::error_ret "Serial port not open"
    }
    if { $S(Writing) } {
        return
    }
    #
    # Setup notifier for end of write operation
    # Wait until write operation finished
    # Remove notifier
    #
    set S(AddrX)     [expr 0x$S(Addr)]
    set S(DataIndex) 0
    set S(Writing)   1

    while {$S(Writing)} {
        ::srec::dump_nextdata
    }
}

# Create the S-Record window
#
proc ::srec::win { {win .send_file} } {
    variable S

    catch { destroy $win }
    toplevel $win
    wm title $win "S-Records"

    set mf [MainFrame $win.frame]
    pack $mf -fill both -expand yes

    $mf addindicator -textvariable ::srec::S(Progress) -width 20

    # NoteBook creation
    #
    set notebook [NoteBook $mf.nb]

    # Send file notebook page
    #
    set nb [$notebook insert end sendfile -text "Send file"]

        set tf [TitleFrame $nb.opt -text "Options" -side left -borderwidth 1]
        pack $tf -side top -expand yes -fill x
        set f [$tf getframe]

            Label $f.t1 -text "Delay: " -anchor w  \
                -helptext "Delay between sending two characters in milliseconds\nWarning: Implemented as Tcl after delay, not very accurate."
            SpinBox $f.sb1 \
                -textvariable ::moni::M(Send.Delay) \
                -width 8 -editable 1 -range {0 10000 1} \
                -helptext [$f.t1 cget -helptext]

                pack $f.t1 $f.sb1 -side left -padx 2 -pady 2

        set tf [TitleFrame $nb.file -text "Select file" -side left -borderwidth 1]
        pack $tf -side top -expand yes -fill both
        set f [$tf getframe]

            set le [LabelEntry $f.fname -label "Binary file: " \
                 -textvariable ::srec::S(FileName) -width 40 \
                 -helptext "Name of a binary file to upload via S-Records"]
            pack $le -side left -expand yes -fill x

            set but [Button $f.browse -text "Browse" -helptext "Browse for file" \
                -command ::srec::select_send_file]
            pack $but -side left -padx 2 -pady 2

        set tf [TitleFrame $nb.addr -text "Address" -side left -borderwidth 1]
        pack $tf -side top -expand yes -fill x
        set f [$tf getframe]

            set f1 [frame $f.f1]
            pack $f1 -side left

            Label $f1.t1 -text "Address size: "   \
                -helptext "Select the target address size"
            radiobutton $f1.s16 -text "16-bit" \
                -variable ::srec::S(AddrSize) -value 16 \
                -command ::srec::address_size
            DynamicHelp::register $f1.s16 balloon "16-bit address size\nWrites S0,S1,S9 records"
            radiobutton $f1.s24 -text "24-bit" \
                -variable ::srec::S(AddrSize) -value 24 \
                -command ::srec::address_size
            DynamicHelp::register $f1.s24 balloon "24-bit address size\nWrites S0,S2,S8 records"
            radiobutton $f1.s32 -text "32-bit" \
                -variable ::srec::S(AddrSize) -value 32 \
                -command ::srec::address_size
            DynamicHelp::register $f1.s32 balloon "32-bit address size\nWrites S0,S3,S7 records"

            Label $f1.t2 -text "Address(hex): " \
                -helptext "The destination address to load"
            Entry $f1.e1 -textvariable ::srec::S(Addr) \
                -validate key -vcmd {::srec::validate_address %P} \
                -helptext [$f1.t2 cget -helptext]
            checkbutton $f1.c1 -text "Execute" \
                -variable ::srec::S(Execute)
            DynamicHelp::register $f1.c1 balloon "Execute address after upload\nWrites S7/S8/S9 record"

            grid $f1.t1 $f1.s16 $f1.s24 $f1.s32 -sticky nw -pady 2
            grid $f1.t2 $f1.e1  -       $f1.c1  -sticky nw -pady 2

            set but [Button $f.send -text "Send" -helptext "Send the file as S-Records" \
                        -width 10 -command ::srec::send_file]
            pack $but -side right -padx 2 -pady 2

    # Send file notebook page
    #
    set nb [$notebook insert end dump -text "Dump data"]

        set tf [TitleFrame $nb.opt -text "Options" -side left -borderwidth 1]
        pack $tf -side top -expand yes -fill x
        set f [$tf getframe]

            Label $f.t1 -text "Delay: " -anchor w  \
                -helptext "Delay between sending two characters in milliseconds\nWarning: Implemented as Tcl after delay, not very accurate."
            SpinBox $f.sb1 \
                -textvariable ::moni::M(Send.Delay) \
                -width 8 -editable 1 -range {0 10000 1} \
                -helptext [$f.t1 cget -helptext]

                pack $f.t1 $f.sb1 -side left -padx 2 -pady 2

        set tf [TitleFrame $nb.addr -text "Address" -side left -borderwidth 1]
        pack $tf -side top -expand yes -fill x
        set f [$tf getframe]

            set f1 [frame $f.f1]
            pack $f1 -side left

            Label $f1.t1 -text "Address size: "   \
                -helptext "Select the target address size"
            radiobutton $f1.s16 -text "16-bit" \
                -variable ::srec::S(AddrSize) -value 16 \
                -command ::srec::address_size
            DynamicHelp::register $f1.s16 balloon "16-bit address size\nWrites SA dump-record (not a standard S-Record)"
            radiobutton $f1.s24 -text "24-bit" \
                -variable ::srec::S(AddrSize) -value 24 \
                -command ::srec::address_size
            DynamicHelp::register $f1.s24 balloon "24-bit address size\nWrites SB dump-record (not a standard S-Record)"
            radiobutton $f1.s32 -text "32-bit" \
                -variable ::srec::S(AddrSize) -value 32 \
                -command ::srec::address_size
            DynamicHelp::register $f1.s32 balloon "32-bit address size\nWrites SC dump-record (not a standard S-Record)"

            Label $f1.t2 -text "Address(hex): " \
                -helptext "The address to dump"
            Entry $f1.e1 -textvariable ::srec::S(Addr) \
                -validate key -vcmd {::srec::validate_address %P} \
                -helptext [$f1.t2 cget -helptext]
            checkbutton $f1.c1 -text "Execute" \
                -variable ::srec::S(Execute)
            DynamicHelp::register $f1.c1 balloon "Execute address after upload\nWrites S7/S8/S9 record"

            Label $f1.t3 -text "Length(hex): " \
                -helptext "The number of bytes to dump"
            Entry $f1.e2 -textvariable ::srec::S(Length) \
                -validate key -vcmd {::srec::validate_address %P} \
                -helptext [$f1.t3 cget -helptext]

            grid $f1.t1 $f1.s16 $f1.s24 $f1.s32 -sticky nw -pady 2
            grid $f1.t2 $f1.e1  -       -       -sticky nw -pady 2
            grid $f1.t3 $f1.e2  -       -       -sticky nw -pady 2

            set but [Button $f.send -text "Dump" -helptext "Dump target data as S-Records" \
                        -width 10 -command ::srec::dump_data]
            pack $but -side right -padx 2 -pady 2


    # NoteBook display
    #
    $notebook compute_size
    pack $notebook -fill both -expand yes -padx 4 -pady 4
    $notebook raise [$notebook page 0]

    ::moni::center_top $win
}


proc ::srec::init {} {
    #
    # Add a menu entry for the S-Record loader
    #
    set menu [.moni getmenu plugins]
    $menu add command -label "S-Record loader" -command ::srec::win
}

::srec::init
