############################################# This is the I/O listening package.
    if {0} {
        #if debugging:
        interp alias {} [namespace current]::dputs {} puts
    } else {
        proc dputs {args} { }
    }

    variable watchId 0

    proc watch {file_or_dir} {
        variable watchId
        incr watchId

        upvar [namespace current]::watch$watchId watching
        if {[info exists [namespace current]::watch$watchId]} {
            array unset [namespace current]::watch$watchId
        }

        set watching(watching) [list]


        if {[file isdir $file_or_dir]} {
            addDir watch$watchId $file_or_dir
        } else {
            add watch$watchId $file_or_dir
        }

        #set initial scan time
        set watching(last) [clock seconds]

        return watch$watchId
    }

    proc add {id name} {
        dputs "add $name"
        upvar [namespace current]::$id watching

        if {[info exists watching(watch.$name)]} {
            dputs "add exists $name"
            #no watching twice!
            return
        }

        lappend watching(watching) $name [file isdir $name]

        #and determine initial time (if any)
        if {[file exists $name]} {
            set itime [file mtime $name]
        } else {
            set itime 0
        }

        set watching(watch.$name) $itime

        return $name
    }

    proc addDir {id dir} {
        dputs "Add dir $dir"
        upvar [namespace current]::$id watching
        if {[info exists watching(watch.$dir)]} {
            dputs "Adddir exists $dir"
            #no watching twice!
            return
        }


        #puts "Add dir $dir"

        lappend new [add $id $dir]
        #puts "glob: [glob -nocomplain -path $dir/ *]"
        foreach file [glob -nocomplain -path $dir/ *] {

            if {[file isdir $file]} {
                dputs "Recurse into $file"
                set new [concat $new [addDir $id $file]]
            } else {
                lappend new [add $id $file]
            }
        }
        return $new
    }

    proc newfiles {id time} {
        upvar [namespace current]::$id watching
        set newer [list]
        foreach {file isdir} $watching(watching) {
            if {$watching(watch.$file) >= $time} {
                lappend newer $file
            }
        }
        return $newer
    }

    proc changes {id} {
        upvar [namespace current]::$id watching
        set changes [list]
        set new [list]
        #puts $watching(watching)
        foreach {file isdir} $watching(watching) {
            #puts "$isdir && [file mtime $file] > $watching(watch.$file)"
            if {$isdir && [file exists $file] && [file mtime $file] > $watching(watch.$file)} {
                set watching(watch.$file) [file mtime $file]
                lappend changes $file update
                foreach item [glob -nocomplain -dir $file *] {
                    if {![info exists watching(watch.$item)]} {
                        if {[file isdir $item]} {
                            set new [concat $new [addDir $id $item]]
                        } else {
                            lappend new [add $id $item]
                        }
                    }
                }
            }
        }
        foreach item $new {
            lappend changes $item created
        }

        return $changes
    }

###############################

set w [watch var]

set last_timestamp 0

after 1000 [list async_watch]

proc async_watch {} {
    global last_timestamp w
    set list_of_files [newfiles $w $last_timestamp]
    puts "Files created since last check: $list_of_files"

    foreach path $list_of_files {
        if { [file isdirectory $path] == 0 } {
            set file_name_parts [split $path "."]
            puts "fnp: $file_name_parts"
            set server [lindex $file_name_parts 1]
            set vessel [lindex $file_name_parts 2]
            puts "vessel $vessel"
            if { $vessel != "irc" } {
                puts $path
                set fp [open $path r]
                set str [read $fp]
                close $fp

                set sep_pos [string first : $str]
                set length [string length $str]

                set username [string range $str 0 [expr $sep_pos -1]]
                set content [string range $str [expr $sep_pos + 1] $length]
                puts "$username  -=- $context"
                putquick "PRIVMSG #discworld :@$username: $content"
                
                file delete $path
            }
        }
    }
    
    set last_timestamp [clock seconds]
    after 1000 [list async_watch]
}


bind pubm - *!*@* bridge_listener
proc bridge_listener {nick userhost handle channel text} {
    if { $channel == "#discworld" } {
         set fp [open "var/[clock milliseconds].discworld.irc.txt" w]
         puts $fp "$nick:$text"
         close $fp
    }
}

vwait 1
