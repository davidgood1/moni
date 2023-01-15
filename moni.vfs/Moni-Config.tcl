##################################################################
# Serial Port Monitor for Windows, Linux, Solaris
# (c) rs@rolf-schroedter.de http://www.rolf-schroedter.de/moni
##################################################################
# $Id: Moni-Config.tcl 1131 2008-02-02 17:13:01Z rolf $
##################################################################
# config_open
#       Open serial port with the current configuration
#
proc ::moni::config_open {} {
    variable M
    variable Cfg

    set M(Chan) [open $Cfg(Port) r+]
    set M(Open) 1
    fconfigure $M(Chan) -translation binary -blocking 0

    set parity [string index $Cfg(Parity) 0]
    set mode $Cfg(Baud),$parity,$Cfg(DataBits),$Cfg(StopBits)
    fconfigure $M(Chan) -buffering none
    fconfigure $M(Chan) -mode $mode -handshake $Cfg(Handshake)
    switch -glob -- $::tcl_platform(os) {
        Windows* {
            fconfigure $M(Chan) -sysbuffer $Cfg(SysBuffer) -pollinterval $Cfg(Pollinterval)
        }
    }
    fileevent $M(Chan) readable ::moni::reader
    set M(TTY.CStat) "online"
}

# config_reopen
#       Reopen serial port with the current configuration
#
proc ::moni::config_reopen {} {
    variable M
    catch {close $M(Chan)}
    ::moni::config_open
}

# close_chan
#       Close the channel without asking for confirmation
#
proc ::moni::close_chan { {clear 1} } {
    variable M

    set M(Open) 0
    catch { close $M(Chan) }

    if {$clear} {
	::moni::term_clear
	::moni::log_close
    }

    set M(TTY.CStat) "offline"
}

# config_close
#       Check wheather config has changed -> Save to file
#       Close serial port
#
proc ::moni::config_close {} {
    variable M

    if { ! $M(Open) } {
        return 1
    }
    if { $M(Config.Changed) } {
        set answer [tk_messageBox -message "Configuration changed, Save?" -type yesnocancel -icon question]
        switch -- $answer {
            yes {   if { ! [::moni::config_save] } {
                        return 0
                    }
                }
            no {    ;# do nothing
            }
            cancel {
                return 0
            }
        }
    }
    ::moni::close_chan
    return 1
}

# config_setup
#       The configuration has changed, reconfigure serial port
#
proc ::moni::config_setup {} {
    variable M
    catch {close $M(Chan)}
    ::moni::config_open
}

# config_edit
#       Edit configuration, then reconfigure serial port
#
proc ::moni::config_edit {} {
    variable M
    variable Cfg

    set result [serialconfig::win .cfg "Serial configuration $M(Config.Name)" Cfg]
    if { $result } {
        set M(Config.Changed) 1
        ::moni::config_setup
    }
}

# config_load_file
#       Load new config from specified file.
#
proc ::moni::config_load_file {} {
    variable M
    variable Cfg

    if { $M(Config.Name) == "" } {
        return
    }

    set filename [file join $M(Config.Dir) $M(Config.Name)]
    if { [catch {open $filename r} file] } {
        ::moni::error_ret "Cannot open $filename"
    }

    set id [string trim [gets $file]]
    if { [string compare $id $M(Config.Id)] != 0 } {
        ::moni::error_ret "File $filename is not a serial port configuration file"
    }

    catch {unset Cfg}
    array set Cfg [read $file]
    close $file

    set M(Config.Changed) 0
}

# config_save
#       Save configuration to file
#
proc ::moni::config_save {} {
    variable M
    variable Cfg

    if { $M(Config.Name) == "" } {
        return [moni::config_save_as]
    }
    set filename [file join $M(Config.Dir) $M(Config.Name)]
    set file [open $filename w]
    puts $file $M(Config.Id)
    foreach index [lsort -dictionary [array names Cfg]] {
        puts $file "[list $index] [list $Cfg($index)]"
    }
    close $file

    set M(Config.Changed) 0
    return 1
}
proc ::moni::config_save_as {} {
    variable M

    set filename [tk_getSaveFile -filetypes $M(Config.FileTypes)    \
                    -defaultextension .cfg                          \
                    -initialdir $M(Config.Dir)                      ]
    if { $filename == "" } {
        return 0
    }

    if { [file exists $filename] && ! [file isfile $filename] } {
        ::moni::error_ret "File \"$filename\" is not a regular file"
    }
    set M(Config.Dir)   [file dirname $filename]
    set M(Config.Name)  [file tail $filename]
    return [moni::config_save]
}

proc ::moni::config_load {} {
    variable M

    if { $M(Open)} {
        ::moni::config_close
    }
    set filename [tk_getOpenFile -filetypes $M(Config.FileTypes)    \
                    -defaultextension .cfg                          \
                    -initialdir $M(Config.Dir)                      ]
    if { $filename == "" } {
        return
    }
    if { ! [file isfile $filename] } {
        ::moni::error_ret "File \"$filename\" is not a regular file"
    }
    set M(Config.Dir)   [file dirname $filename]
    set M(Config.Name)  [file tail $filename]
    ::moni::config_load_file
    ::moni::config_open
}
proc ::moni::config_new {} {
    variable M

    if { $M(Open)} {
        ::moni::config_close
    }
    set M(Config.Name)  ""
    ::moni::config_edit
}

# Reflect configuration name and changed-status in window title
#
proc ::moni::config_changed { name index op } {
    ::moni::win_title
}
trace variable ::moni::M(Open) w ::moni::config_changed
trace variable ::moni::M(Config.Name) w ::moni::config_changed
trace variable ::moni::M(Config.Changed) w ::moni::config_changed
