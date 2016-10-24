#------------------------------------------------------------------------------
#
#	Tcl DataBase Connectivity JDBC Driver
#	Class definitions and Tcl-level methods for the tdbc::jdbc bridge.
#
#------------------------------------------------------------------------------

package require Tcl 8.6
package require tdbc

# jtclsh will setup TCLLIBPATH
if { [info exists ::env(TCLLIBPATH) ] } {
    if {[catch {package require java}]} {
        puts "Failed loading package TclBlend..."
	exit
    }
} else {
    # Environment variable does not find TCLLIBPATH -> no TclBlend/jtclsh
    # Now try to check TclJBlend
    if {[catch {package require JBlend}]} {
        puts "Failed loading package TclJBlend, exit."
	exit
    }
}

package provide tdbc::jdbc 0.1.1


::namespace eval ::tdbc::jdbc {

    namespace export connection

}


java::import java.sql.Connection
java::import java.sql.DriverManager
java::import java.sql.ResultSet
java::import java.sql.SQLWarning
java::import java.sql.Statement
java::import java.sql.ResultSetMetaData
java::import java.sql.DatabaseMetaData
java::import java.sql.Date
java::import java.sql.Time
java::import java.sql.Timestamp
java::import java.math.BigDecimal
java::import java.io.ByteArrayInputStream
java::import java.io.Reader
java::import java.io.StringReader


#------------------------------------------------------------------------------
#
# tdbc::jdbc::connection --
#
#	Class representing a connection to a jdbc database.
#
#-------------------------------------------------------------------------------

::oo::class create ::tdbc::jdbc::connection {

    superclass ::tdbc::connection

    variable ConnectionI DatabaseMetaDataI
    variable isolation
    variable readonly
    variable transaction
    variable useprepared

    constructor {className url username password args} {
        next

        if {[llength $args] % 2 != 0} {
            set cmd [lrange [info level 0] 0 end-[llength $args]]
            return -code error \
            -errorcode {TDBC GENERAL_ERROR HY000 JDBC WRONGNUMARGS} \
            "wrong # args, should be \"$cmd ?-option value?...\""
        }

        java::try {
            java::call Class forName $className
            set ConnectionI [ java::call DriverManager getConnection $url $username $password ]
        } catch {TclException ex} {
            error "a Tcl error occurred"
        } catch {ClassNotFoundException ex} {
            error "catch ClassNotFoundException, please check CLASSPATH"
        } catch {SQLException ex} {
            error "catch SQLException, Connection fail"
        }

        # for internal use
        set transaction [dict create \
            1 readuncommitted \
            2 readcommitted \
            4 repeatableread \
            8 serializable]

        set DatabaseMetaDataI {}
        set isolation [ $ConnectionI getTransactionIsolation ]
        set readonly  [ $ConnectionI isReadOnly ]
        set useprepared 1

        if {[llength $args] > 0} {
            my configure {*}$args
        }

    }

    forward statementCreate ::tdbc::jdbc::statement create


    method configure args {
        if {[llength $args] == 0} {
            set result -isolation
            lappend result [dict get $transaction $isolation]
            lappend result -readonly $readonly
            return $result
        } elseif {[llength $args] == 1} {
            set option [lindex $args 0]
            switch -exact -- $option {
                -i - -is - -iso - -isol - -isola - -isolat - -isolati -
                -isolatio - -isolation {
                    return [dict get $transaction $isolation]
                }
                -r - -re - -rea - -read - -reado - -readon - -readonl -
                -readonly {
                    return $readonly
                }
                default {
                    return -code error \
                    -errorcode [list TDBC GENERAL_ERROR HY000 JDBC \
                            BADOPTION $option] \
                    "bad option \"$option\": must be -isolation or -readonly"

                }
            }
        } elseif {[llength $args] % 2 != 0} {
            set cmd [lrange [info level 0] 0 end-[llength $args]]
            return -code error \
            -errorcode [list TDBC GENERAL_ERROR HY000 \
                    JDBC WRONGNUMARGS] \
            "wrong # args, should be \" $cmd ?-option value?...\""
        }

        foreach {option value} $args {
            switch -exact -- $option {
                -i - -is - -iso - -isol - -isola - -isolat - -isolati -
                -isolatio - -isolation {
                    switch -exact -- $value {
                    readu - readun - readunc - readunco - readuncom -
                    readuncomm - readuncommi - readuncommit -
                    readuncommitt - readuncommitte - readuncommitted {
                        $ConnectionI setTransactionIsolation 1
                        set isolation [ $ConnectionI getTransactionIsolation ]
                    }
                    readc - readco - readcom - readcomm - readcommi -
                    readcommit - readcommitt - readcommitte -
                    readcommitted {
                        $ConnectionI setTransactionIsolation 2
                        set isolation [ $ConnectionI getTransactionIsolation ]
                    }
                    rep - repe - repea - repeat - repeata - repeatab -
                    repeatabl - repeatable - repeatabler - repeatablere -
                    repeatablerea - repeatablread {
                        $ConnectionI setTransactionIsolation 4
                        set isolation [ $ConnectionI getTransactionIsolation ]
                    }
                    s - se - ser - seri - seria - serial - seriali -
                    serializ - serializa - serializab - serializabl -
                    serializable -
                    reado - readon - readonl - readonly {
                        $ConnectionI setTransactionIsolation 8
                        set isolation [ $ConnectionI getTransactionIsolation ]
                    }
                    default {
                        return -code error \
                        -errorcode [list TDBC GENERAL_ERROR HY000 \
                                JDBC BADISOLATION $value] \
                        "bad isolation level \"$value\":\
                                        should be readuncommitted, readcommitted,\
                                        repeatableread, serializable, or readonly"
                    }
                    }
                }
                -r - -re - -rea - -read - -reado - -readon - -readonl -
                -readonly {
                    $ConnectionI setReadOnly $value
                    set readonly  [ $ConnectionI isReadOnly ]
                }
                default {
                    return -code error \
                    -errorcode [list TDBC GENERAL_ERROR HY000 \
                            JDBC BADOPTION $value] \
                    "bad option \"$option\": must be\
                                 -isolation or -readonly"
                }
            }
        }
        return
    }


    # invoke close method -> destroy our object
    method close {} {
        set mystats [my statements]
        foreach mystat $mystats {
            $mystat close
        }
        unset mystats

        $ConnectionI close

        next
    }


    method tables {{pattern %}} {
        set retval {}

        set DatabaseMetaDataI [ $ConnectionI getMetaData ]
        set result [ $DatabaseMetaDataI getTables [java::null] [java::null] $pattern [java::null] ]

        while { [$result next]} {
            set row [dict create]
            dict set row "TABLE_CAT" [$result getString "TABLE_CAT"]
            dict set row "TABLE_SCHEM" [$result getString "TABLE_SCHEM"]
            dict set row "TABLE_NAME" [$result getString "TABLE_NAME"]
            dict set row "TABLE_TYPE" [$result getString "TABLE_TYPE"]

            dict set retval [dict get $row TABLE_NAME] $row
        }

        return $retval
    }


    method columns {table {pattern %}} {
        set retval {}

        # Setup our pattern
        set pattern [string map [list \
                                 * {[*]} \
                                 ? {[?]} \
                                 \[ \\\[ \
                                 \] \\\[ \
                                 _ ? \
                                 % *] $pattern]

        set sql  "select * from $table where 1 = 0"

        set stmt [$ConnectionI createStatement]
        set query [$stmt executeQuery $sql]
        set meta  [$query getMetaData]

        set count [$meta getColumnCount]

        for {set i 1} {$i <= $count} {incr i 1} {
            set column_name [$meta getColumnLabel $i]
            if {![string match $pattern $column_name]} {
                continue
            }

            set row [dict create]
            dict set row name $column_name
            dict set row type [string tolower [$meta getColumnTypeName $i]]
            dict set row precision [$meta getPrecision $i]
            dict set row scale [$meta getScale $i]
            dict set row nullable [$meta isNullable $i]

            dict set retval [dict get $row name] $row
        }

        $query close
        $stmt close

        return $retval
    }


    method primarykeys {table} {
        set retval {}

        set DatabaseMetaDataI [ $ConnectionI getMetaData ]
        set result [$DatabaseMetaDataI getPrimaryKeys [java::null] [java::null] $table]
        while { [$result next]} {
            set row [dict create]
            dict set row "TABLE_CAT" [$result getString "TABLE_CAT"]
            dict set row "TABLE_SCHEM" [$result getString "TABLE_SCHEM"]
            dict set row "TABLE_NAME" [$result getString "TABLE_NAME"]
            dict set row "COLUMN_NAME" [$result getString "COLUMN_NAME"]

            dict set retval [dict get $row COLUMN_NAME] $row
        }

        return $retval
    }


    method foreignkeys {args} {
        set retval {}
        set length [llength $args]
        set ftable ""

        if { $length != 2 || $length%2 != 0} {
            return -code error \
            -errorcode [list TDBC GENERAL_ERROR HY000 \
                    JDBC WRONGNUMARGS] \
            "wrong # args: should be \
             [lrange [info level 0] 0 1] -foreign tableName"

            return $retval
        }

        foreach {key table} $args {
            if {[string compare $key "-foreign"]==0} {
                set ftable $table
            } else {
                return $retval
            }
        }

        set DatabaseMetaDataI [ $ConnectionI getMetaData ]
        set result [$DatabaseMetaDataI getImportedKeys [java::null] [java::null] $ftable]

        while { [$result next]} {
            set row [dict create]
            set fktable [$result getString "FKTABLE_NAME"]
            set fkschem [$result getString "FKTABLE_SCHEM"]
            set fkcolumn [$result getString "FKCOLUMN_NAME"]

            set pktable [$result getString "PKTABLE_NAME"]
            set pkschem [$result getString "PKTABLE_SCHEM"]
            set pkcolumn [$result getString "PKCOLUMN_NAME"]


            if {[string compare $ftable $fktable]==0} {

                if { [catch {dict get $retval foreignTable}]} {
                   set vallist [list $fktable]
                } else {
                   if {$fktable ni $vallist} {
                       lappend vallist $fktable
                   }
                }
                dict set retval foreignTable $vallist

                if { [catch {set vallist2 [dict get $retval foreignSchema]}]} {
                   set vallist2 [list $fkschem]
                } else {
                   if {$fkschem ni $vallist2} {
                       lappend vallist2 $fkschem
                   }
                }
                dict set retval foreignSchema $vallist2

                if { [catch {set listval [dict get $retval foreignColumn]}]} {
                   set listval [list $fkcolumn]
                } else {
                   if {$fkcolumn ni $listval} {
                       lappend listval $fkcolumn
                   }
                }
                dict set retval foreignColumn $listval

                # Get primary key info
                if { [catch {set primaryvallist [dict get $retval primaryTable]}] } {
                   set primaryvallist [list $pktable]
                } else {
                   if {$pktable ni $primaryvallist} {
                       lappend primaryvallist $pktable
                   }
                }
                dict set retval primaryTable $primaryvallist

                if { [catch {set primaryvallist2 [dict get $retval primarySchema]}]} {
                   set primaryvallist2 [list $pkschem]
                } else {
                   if {$pkschem ni $primaryvallist2} {
                       lappend primaryvallist2 $pkschem
                   }
                }
                dict set retval primarySchema $primaryvallist2

                if { [catch {set primarylistval [dict get $retval primaryColumn]}]} {
                   set primarylistval [list $pkcolumn]
                } else {
                   if {$pkcolumn ni $primarylistval} {
                       lappend primarylistval $pkcolumn
                   }
                }
                dict set retval primaryColumn $primarylistval

            }
        }

        return $retval
    }


    # The 'prepareCall' method gives a portable interface to prepare
    # calls to stored procedures.  It delegates to 'prepare' to do the
    # actual work.
    method preparecall {call} {
        regexp {^[[:space:]]*(?:([A-Za-z_][A-Za-z_0-9]*)[[:space:]]*=)?(.*)} \
            $call -> varName rest
        if {$varName eq {}} {
            my prepare \\{$rest\\}
        } else {
            my prepare \\{:$varName=$rest\\}
        }
    }


    # The 'begintransaction' method launches a database transaction
    method begintransaction {} {
        $ConnectionI setAutoCommit 0
    }


    # The 'commit' method commits a database transaction
    method commit {} {
        $ConnectionI commit
        $ConnectionI setAutoCommit 1
    }


    # The 'rollback' method abandons a database transaction
    method rollback {} {
        $ConnectionI rollback
        $ConnectionI setAutoCommit 1
    }


    method prepare {sqlCode} {
        set result [next $sqlCode]
        return $result
    }


    method getDBhandle {} {
        return $ConnectionI
    }


    method setUsePrepared {flag} {
        set useprepared $flag
    }


    method getUsePrepared {} {
        return $useprepared
    }


    # For debug use
    method getProductName {} {
        set DatabaseMetaDataI [ $ConnectionI getMetaData ]
        set productNmae [ $DatabaseMetaDataI getDatabaseProductName ]
        return $productNmae
    }


    # For debug use
    method getProductVersion {} {
        set DatabaseMetaDataI [ $ConnectionI getMetaData ]
        set productVersion [ $DatabaseMetaDataI getDatabaseProductVersion ]
        return $productVersion
    }

}


#------------------------------------------------------------------------------
#
# tdbc::jdbc::statement --
#
#	The class 'tdbc::jdbc::statement' models one statement against a
#       database accessed through a jdbc connection
#
#------------------------------------------------------------------------------

::oo::class create ::tdbc::jdbc::statement {

    superclass ::tdbc::statement

    variable Params ConnectionI sql useprepared stmt

    constructor {connection sqlcode} {
        next
        set Params {}
        set ConnectionI [$connection getDBhandle]
        set sql {}
        set useprepared [$connection getUsePrepared ]
        foreach token [::tdbc::tokenize $sqlcode] {

            # I have no idea how to get params meta here,
            # just give a default value.
            if {[string index $token 0] in {$ : @}} {
                dict set Params [string range $token 1 end] \
                    {type varchar direction in}

                append sql "?"
                continue
            }

            append sql $token
        }

        java::try {
            if {$useprepared} {
                set stmt [$ConnectionI prepareStatement $sql]
            } else {
                set stmt [$ConnectionI createStatement]
            }
        } catch {SQLException e} {
            error "SQLException when prepareStatement/Statement execute"
        }

    }

    forward resultSetCreate ::tdbc::jdbc::resultset create


    method close {} {
        set mysets [my resultsets]
        foreach myset $mysets {
            $myset close
        }
        unset mysets

        $stmt close

        next
    }


    # The 'params' method returns descriptions of the parameters accepted
    # by the statement
    method params {} {
        return $Params
    }


    method paramtype args {
        set length [llength $args]

        if {$length < 2} {
            set cmd [lrange [info level 0] 0 end-[llength $args]]
            return -code error \
            -errorcode {TDBC GENERAL_ERROR HY000 jdbc WRONGNUMARGS} \
            "wrong # args...\""
        }

        set parameter [lindex $args 0]
        if { [catch  {set value [dict get $Params $parameter]}] } {
            set cmd [lrange [info level 0] 0 end-[llength $args]]
            return -code error \
            -errorcode {TDBC GENERAL_ERROR HY000 jdbc BADOPTION} \
            "wrong param...\""
        }

        set count 1
        if {$length > 1} {
            set direction [lindex $args $count]

            if {$direction in {in out inout}} {
                # I don't know how to setup direction, setup to in
                dict set value direction in
                incr count 1
            }
        }

        if {$length > $count} {
            set type [lindex $args $count]

            # Only accept these types
            if {$type in {bit tinyint smallint integer bigint \
                          char varchar longvarchar clob real float double \
                          date time timestamp decimal numeric binary \
                          varbinary longvarbinary blob}} {
                dict set value type $type
            }
        }

        # Skip other parameters and setup
        dict set Params $parameter $value

    }


    method getStmthandle {} {
        return $stmt
    }


    method getSql {} {
        return $sql
    }


    method getUsePrepared {} {
        return $useprepared
    }


}


#------------------------------------------------------------------------------
#
# tdbc::jdbc::resultset --
#
#	The class 'tdbc::jdbc::resultset' models the result set that is
#	produced by executing a statement against a jdbc database.
#
#------------------------------------------------------------------------------

::oo::class create ::tdbc::jdbc::resultset {

    superclass ::tdbc::resultset

    variable -set {*}{
        -stmt -sql -sqltypes -ResultSetI -ResultSetMetaDataI -params -RowCount
         -columns -columnCount -useprepared
    }


    constructor {statement args} {
        next
    	set -stmt [$statement getStmthandle]
        set -params  [$statement params]
        set -sql [$statement getSql]
        set -useprepared [$statement getUsePrepared]
        set -ResultSetI {}
        set -ResultSetMetaDataI {}
        set -columns {}
        set -columnCount  0
        set -sqltypes {}

        if {[llength $args] == 0} {

            set keylist [dict keys ${-params}]
            set count 1

            # Using java::try to catch exception -> return error is OK?
            java::try {
                foreach mykey $keylist {

                    if {[info exists ::$mykey] == 1} {
                        upvar 1 $mykey mykey1
                        set -sqltypes [dict get [dict get ${-params} $mykey] type]

                        switch -exact -- ${-sqltypes} {
                            bit {
                                ${-stmt}  setBoolean $count $mykey1
                            }
                            tinyint {
                                ${-stmt}  setByte $count $mykey1
                            }
                            smallint {
                                ${-stmt}  setShort $count $mykey1
                            }
                            integer {
                                ${-stmt}  setInt $count $mykey1
                            }
                            bigint {
                                ${-stmt}  setLong $count $mykey1
                            }
                            real {
                                ${-stmt}  setFloat $count $mykey1
                            }
                            float - double {
                                ${-stmt}  setDouble $count $mykey1
                            }
                            char - varcahr - longvarchar {
                                ${-stmt}  setString $count $mykey1
                            }
                            clob {
                                # only work for type 4 JDBC driver
                                set myclob [java::new StringReader $mykey1 ]
                                ${-stmt}  setCharacterStream $count $myclob
                            }
                            date {
                                # Get the Date string YYYY-MM-DD, convert to Java SQL type
                                set mydate [java::call java.sql.Date valueOf $mykey1]
                                ${-stmt}  setDate $count $mydate
                            }
                            time {
                                # Get the Time string HH:mm:ss, convert to Java SQL type
                                set mytime [java::call java.sql.Time valueOf $mykey1]
                                ${-stmt}  setTime $count $mytime
                            }
                            timestamp {
                                # Get the HH:mm:ss HH:mm:ss.S string, convert to Java SQL type
                                set mytimestamp [java::call java.sql.Timestamp valueOf $mykey1]
                                ${-stmt}  setTimestamp $count $mytimestamp
                            }
                            decimal - numeric {
                                # Try convert our string to a BigDecimal object
                                set mynumeric [java::new java.math.BigDecimal $mykey1]
                                ${-stmt}  setBigDecimal $count $mynumeric
                            }
                            binary - varbinary - longvarbinary - blob {
                                # Try to use UTF-8 encoding
                                set charsetName [java::new String "UTF-8"]
                                set jstring [java::new String $mykey1]
                                set bytearray [java::new ByteArrayInputStream [$jstring getBytes $charsetName] ]
                                ${-stmt}  setBinaryStream $count $bytearray
                            }
                            default {
                                # maybe it is wrong
                                ${-stmt}  setString $count $mykey1
                            }
                        }
                    } else {
                        set -sqltypes [dict get [dict get ${-params} $mykey] type]

                        switch -exact -- ${-sqltypes} {
                            bit {
                                set opt1 [java::field java.sql.Types BOOLEAN ]
                            }
                            tinyint {
                                set opt1 [java::field java.sql.Types TINYINT ]
                            }
                            smallint {
                                set opt1 [java::field java.sql.Types SMALLINT ]
                            }
                            integer {
                                set opt1 [java::field java.sql.Types INTEGER ]
                            }
                            bigint {
                                set opt1 [java::field java.sql.Types BIGINT ]
                            }
                            real {
                                set opt1 [java::field java.sql.Types FLOAT ]
                            }
                            float {
                                set opt1 [java::field java.sql.Types FLOAT ]
                            }
                            double {
                                set opt1 [java::field java.sql.Types DOUBLE ]
                            }
                            char {
                                set opt1 [java::field java.sql.Types CHAR ]
                            }
                            varchar {
                                set opt1 [java::field java.sql.Types VARCHAR ]
                            }
                            longvarchar {
                                set opt1 [java::field java.sql.Types LONGVARCHAR ]
                            }
                            clob {
                                set opt1 [java::field java.sql.Types CLOB ]
                            }
                            date {
                                set opt1 [java::field java.sql.Types DATE ]
                            }
                            time {
                                set opt1 [java::field java.sql.Types TIME]
                            }
                            timestamp {
                                set opt1 [java::field java.sql.Types TIMESTAMP]
                            }
                            decimal {
                                set opt1 [java::field java.sql.Types DECIMAL]
                            }
                            numeric {
                                set opt1 [java::field java.sql.Types NUMERIC]
                            }
                            binary {
                                set opt1 [java::field java.sql.Types BINARY]
                            }
                            varbinary {
                                set opt1 [java::field java.sql.Types VARBINARY]
                            }
                            longvarbinary {
                                set opt1 [java::field java.sql.Types LONGVARBINARY]
                            }
                            blob {
                                set opt1 [java::field java.sql.Types BLOB]
                            }
                            default {
                                # maybe it is wrong
                                set opt1 [java::field java.sql.Types VARCHAR]
                            }
                        }

                        ${-stmt}  setNull $count $opt1
                    }

                    incr count 1
                }

                if {${-useprepared}} {
                    set result [ ${-stmt} execute ]
                } else {
                    set result [ ${-stmt} execute ${-sql} ]
                }
            } catch {SQLException e} {
                error "SQLException when execute"
            } catch {Exception e} {
                error "Exception when execute"
            }

            if { $result != 0 } {
                set -ResultSetI [${-stmt} getResultSet]
                set -ResultSetMetaDataI [ ${-ResultSetI} getMetaData ]
                set -columnCount [ ${-ResultSetMetaDataI} getColumnCount ]
                set -RowCount 0
            } else {
                set -RowCount [${-stmt} getUpdateCount]
            }

        } elseif {[llength $args] == 1} {

            # If the dict parameter is supplied, it is searched for a key
            # whose name matches the name of the bound variable
            set -paramDict [lindex $args 0]

            set keylist [dict keys ${-params}]
            set count 1

            # Using java::try to catch exception -> return error is OK?
            java::try {

                foreach mykey $keylist {

                    if {[catch {set bound [dict get ${-paramDict} $mykey]}]==0} {
                        set -sqltypes [dict get [dict get ${-params} $mykey] type]

                        switch -exact -- ${-sqltypes} {
                            bit {
                                ${-stmt}  setBoolean $count $bound
                            }
                            tinyint {
                                ${-stmt}  setByte $count $bound
                            }
                            smallint {
                                ${-stmt}  setShort $count $bound
                            }
                            integer {
                                ${-stmt}  setInt $count $bound
                            }
                            bigint {
                                ${-stmt}  setLong $count $bound
                            }
                            real {
                                ${-stmt}  setFloat $count $bound
                            }
                            float - double {
                                ${-stmt}  setDouble $count $bound
                            }
                            char - varcahr - longvarchar {
                                ${-stmt}  setString $count $bound
                            }
                            clob {
                                # only work for type 4 JDBC driver
                                set myclob [java::new StringReader $bound ]
                                ${-stmt}  setCharacterStream $count $myclob
                            }
                            date {
                                # Get the Date string YYYY-MM-DD, convert to Java SQL type
                                set mydate [java::call java.sql.Date valueOf $bound]
                                ${-stmt}  setDate $count $mydate
                            }
                            time {
                                # Get the Time string HH:mm:ss, convert to Java SQL type
                                set mytime [java::call java.sql.Time valueOf $bound]
                                ${-stmt}  setTime $count $mytime
                            }
                            timestamp {
                                # Get the HH:mm:ss HH:mm:ss.S string, convert to Java SQL type
                                set mytimestamp [java::call java.sql.Timestamp valueOf $bound]
                                ${-stmt}  setTimestamp $count $mytimestamp
                            }
                            decimal - numeric {
                                # Try convert our string to a BigDecimal object
                                set mynumeric [java::new java.math.BigDecimal $bound]
                                ${-stmt}  setBigDecimal $count $mynumeric
                            }
                            binary - varbinary - longvarbinary - blob {
                                # Try to use UTF-8 encoding
                                set charsetName [java::new String "UTF-8"]
                                set jstring [java::new String $bound]
                                set bytearray [java::new ByteArrayInputStream [$jstring getBytes $charsetName] ]
                                ${-stmt}  setBinaryStream $count $bytearray
                            }
                            default {
                                # maybe it is wrong
                                ${-stmt}  setString $count $bound
                            }
                        }
                    } else {
                        set -sqltypes [dict get [dict get ${-params} $mykey] type]

                        switch -exact -- ${-sqltypes} {
                            bit {
                                set opt1 [java::field java.sql.Types BOOLEAN ]
                            }
                            tinyint {
                                set opt1 [java::field java.sql.Types TINYINT ]
                            }
                            smallint {
                                set opt1 [java::field java.sql.Types SMALLINT ]
                            }
                            integer {
                                set opt1 [java::field java.sql.Types INTEGER ]
                            }
                            bigint {
                                set opt1 [java::field java.sql.Types BIGINT ]
                            }
                            real {
                                set opt1 [java::field java.sql.Types FLOAT ]
                            }
                            float {
                                set opt1 [java::field java.sql.Types FLOAT ]
                            }
                            double {
                                set opt1 [java::field java.sql.Types DOUBLE ]
                            }
                            char {
                                set opt1 [java::field java.sql.Types CHAR ]
                            }
                            varchar {
                                set opt1 [java::field java.sql.Types VARCHAR ]
                            }
                            longvarchar {
                                set opt1 [java::field java.sql.Types LONGVARCHAR ]
                            }
                            clob {
                                set opt1 [java::field java.sql.Types CLOB ]
                            }
                            date {
                                set opt1 [java::field java.sql.Types DATE ]
                            }
                            time {
                                set opt1 [java::field java.sql.Types TIME]
                            }
                            timestamp {
                                set opt1 [java::field java.sql.Types TIMESTAMP]
                            }
                            decimal {
                                set opt1 [java::field java.sql.Types DECIMAL]
                            }
                            numeric {
                                set opt1 [java::field java.sql.Types NUMERIC]
                            }
                            binary {
                                set opt1 [java::field java.sql.Types BINARY]
                            }
                            varbinary {
                                set opt1 [java::field java.sql.Types VARBINARY]
                            }
                            longvarbinary {
                                set opt1 [java::field java.sql.Types LONGVARBINARY]
                            }
                            blob {
                                set opt1 [java::field java.sql.Types BLOB]
                            }
                            default {
                                # maybe it is wrong
                                set opt1 [java::field java.sql.Types VARCHAR]
                            }
                        }

                        ${-stmt}  setNull $count $opt1
                    }

                    incr count 1
                }

                if {${-useprepared}} {
                    set result [ ${-stmt} execute ]
                } else {
                    set result [ ${-stmt} execute ${-sql} ]
                }
            } catch {SQLException e} {
                error "SQLException when execute"
            } catch {Exception e} {
                error "Exception when execute"
            }

            if { $result != 0 } {
                set -ResultSetI [${-stmt} getResultSet]
                set -ResultSetMetaDataI [ ${-ResultSetI} getMetaData ]
                set -columnCount [ ${-ResultSetMetaDataI} getColumnCount ]
                set -RowCount 0
            } else {
                set -RowCount [${-stmt} getUpdateCount]
            }

        } else {
            return -code error \
            -errorcode [list TDBC GENERAL_ERROR HY000 \
                    JDBC WRONGNUMARGS] \
            "wrong # args: should be\
                     [lrange [info level 0] 0 1] statement ?dictionary?"
        }
    }


    # Return a list of the columns
    method columns {} {
        variable columnName

        set -columns {}
        set i 1
        while { $i <= ${-columnCount} } {
            set columnName [ ${-ResultSetMetaDataI} getColumnLabel $i ]
            lappend -columns $columnName
            incr i
        }

        return ${-columns}
    }


    method nextresults {} {
        set have 0

        if { [catch {set have [ ${-ResultSetMetaDataI} isAfterLast ] } ] } {
            set have 0
        }

        return $have
    }


    method nextlist var {
        upvar 1 $var row
        set row {}
        set i 1

        if { [ ${-ResultSetI} next ] == 1 } {
            while { $i <= ${-columnCount} } {
                set columnName [ ${-ResultSetMetaDataI} getColumnLabel $i ]
                set columnType [ ${-ResultSetMetaDataI} getColumnTypeName $i ]

                # Add BLOB handle
                set columnType [string tolower $columnType]
                if {$columnType in {"blob" "binary" "varbinary" "longvarbinary" "bytea" "raw" "longraw" "image"}} {
                    set charsetName [java::new String "UTF-8"]
                    set mybytes [${-ResultSetI} getBytes $columnName]
                    set jstring [java::new String $mybytes $charsetName]
                    set value [$jstring toString]
                } else {
                    set value [ ${-ResultSetI} getString $columnName ]
                }

                if { [ ${-ResultSetI} wasNull] } {
                    lappend row ""
                } else {
                    lappend row $value
                }

                incr i 1
            }
        } else {
            return 0
        }

        return 1
    }


    method nextdict var {
        upvar 1 $var row
        set row {}
        set i 1

        set row [dict create]

        if { [  ${-ResultSetI} next ] == 1 } {
            while { $i <= ${-columnCount} } {
                set columnName [ ${-ResultSetMetaDataI} getColumnLabel $i ]
                set columnType [ ${-ResultSetMetaDataI} getColumnTypeName $i ]

                # Add BLOB handle
                set columnType [string tolower $columnType]
                if {$columnType in {"blob" "binary" "varbinary" "longvarbinary" "bytea" "raw" "longraw" "image"}} {
                    set charsetName [java::new String "UTF-8"]
                    set mybytes [${-ResultSetI} getBytes $columnName]
                    set jstring [java::new String $mybytes $charsetName]
                    set value [$jstring toString]
                } else {
                    set value [ ${-ResultSetI} getString $columnName ]
                }

                if {[ ${-ResultSetI} wasNull] == 0} {
                    dict set row $columnName $value
                }

                incr i 1
            }
        } else {
            return 0
        }

        return 1
    }


    # Return the number of rows affected by a statement
    method rowcount {} {
        return ${-RowCount}
    }
}
