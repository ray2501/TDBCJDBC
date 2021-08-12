#
# A small program to combine tdbc::jdbc, linenoise and tabulate
#

package require tdbc::jdbc

set isLinenoise 0
if {[catch {package require linenoise}]==0} {
    set isLinenoise 1
}

source tabulate.tcl

# Setup parameters
set className    {org.postgresql.Driver}
set url          jdbc:postgresql://localhost:5432/danilo
set username     danilo
set password     danilo

try {
    tdbc::jdbc::connection create db $className $url $username $password -readonly 0
} on error {em} {
    puts $em
    exit
}

puts "Please input exit or quit to leave."
puts ""

while {1} {
    if {$isLinenoise == 0} {
        puts -nonewline stdout "SQL> "
        flush stdout
        gets stdin query
    } else {
        set query [linenoise prompt \
               -prompt "\033\[1;33mSQL\033\[0m> "]
    }

    switch $query {
        "exit" -
        "quit" {
            puts ""
            puts "Have a nice time, bye bye~~~"
            exit
        }
        default {
            try {
                set statement [db prepare $query]
                set resultset [$statement execute]

                set columns [$resultset columns]
                if {[llength $columns] != 0} {
                    set result [list]
                    set columnlist [list]
                    foreach c $columns {
                        lappend columnlist $c
                    }

                    lappend result $columnlist

                    $resultset foreach -as lists row {
                         lappend result $row
                    }

                    puts ""
                    puts [::tabulate::tabulate -data $result]
                }

                $resultset close
                $statement close
            } on error {em} {
                puts "Error: $em"
            }
        }
    }
}

db close
