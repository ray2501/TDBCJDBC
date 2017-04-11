TDBCJDBC
=====

It is unofficial Tcl DataBase Connectivity JDBC Driver.

[Tcl Database Connectivity (TDBC)](http://www.tcl.tk/man/tcl8.6/TdbcCmd/tdbc.htm)
is a common interface for Tcl programs to access SQL databases.

[tclBlend](http://tcljava.sourceforge.net/docs/website/index.html) is a Tcl package
that provides access to Java classes from Tcl. tclBlend is implemented using 
[JNI](https://en.wikipedia.org/wiki/Java_Native_Interface).

[tclJBlend](http://wiki.tcl.tk/47668) is a fork of TclBlend, a Tcl extension that
uses JNI to communicate with a Java interpreter.

[Java Database Connectivity (JDBC)](https://en.wikipedia.org/wiki/Java_Database_Connectivity) provides methods to query and update data in a database, and is oriented towards relational databases.

The library consists of a single [Tcl Module](http://tcl.tk/man/tcl8.6/TclCmd/tm.htm#M9) file.
TDBC::JDBC extension is using tclBlend package to call JDBC API.

The tdbc::jdbc driver provides a database interface that conforms to Tcl DataBase Connectivity (TDBC)
and allows a Tcl script to connect to any SQL database presenting a JDBC interface.
Now it is a limited support implement.

Only test on openSUSE LEAP 42.1 (64bit), Ubuntu 14.04 (64bit) and Open JDK7,
Windows platform (32bit and 64bit) and JDK8.

This extension needs Tcl >= 8.6, TDBC and tclBlend (or tclJBlend) package.
Tcl 8.6.1-8.6.5 maybe need patch, please
check [tclBlend](http://wiki.tcl.tk/1313).


License
=====

MIT License


Installation
=====

The tdbc::jdbc driver requires Tcl >= 8.6, TDBC and tclBlend package.

For Windows platform, if your Tcl lib folder is `C:\Tcl\lib`,
then copy jdbc-0.1.1.tm this file to below location:

    C:\Tcl\lib\tcl8\8.6\tdbc

For Ubuntu, copy jdbc-0.1.1.tm this file to below location:

    /usr/share/tcltk/tcl8/8.6/tdbc

For openSUSE (64bit), copy jdbc-0.1.1.tm this file to below location:

    /usr/lib64/tcl/tcl8/8.6/tdbc

Or you can use installer.tcl to install this package.
`install.tcl` use `info library` to get path and install tm file.
If you want to uninstall after using install.tcl to install,
try below command:

    sudo ./install.tcl -uninstall 1


Commands
=====

tdbc::jdbc::connection create db className url username password ?-option value...?

Connection to a JDBC database is established by invoking `tdbc::jdbc::connection create`,
passing it the name to be used as a connection handle, followed by a JDBC driver class name,
JDBC url, username and password.

The tdbc::jdbc::connection create object command supports the -isolation and -readonly options.

JDBC driver for TDBC implements a statement object that represents a SQL statement in a database.
Instances of this object are created by executing the `prepare` or `preparecall` object
command on a database connection.

The `prepare` object command against the connection accepts arbitrary SQL code
to be executed against the database.

The `paramtype` object command allows the script to specify the type and
direction of parameter transmission of a variable in a statement.
Now JDBC driver only specify the type work.

JDBC driver paramtype accepts below type:  
bigint, binary, bit, char, date, decimal, double, float, integer,
longvarbinary, longvarchar, numeric, real, time, timestamp, smallint,
tinyint, varbinary, varchar, blob and clob.

The `execute` object command executes the statement.


Examples
=====

Before execute TDBC::JDBC package, please setup CLASSPATH correctly.
Below is an example for HSQLDB (on Windows platform):

    set CLASSPATH=c:\jars\hsqldb.jar;%CLASSPATH%


## Example: HSQLDB

[HSQLDB](http://hsqldb.org/) is a relational database management system written in Java.
It offers a fast, small database engine which offers both in-memory and
disk-based tables. Both embedded and server modes are available for purchase.

Below is an exmaple:

    package require tdbc::jdbc

    set className    {org.hsqldb.jdbc.JDBCDriver}
    set url          jdbc:hsqldb:file:testdb 
    set username     SA
    set password     ""

    if {[catch {tdbc::jdbc::connection create db $className $url $username $password -readonly 0} errMsg]} {
        puts $errMsg
        exit
    }

    set statement [db prepare {create table if not exists person (id integer not null, name varchar(40))}]
    $statement execute
    $statement close
    
    set statement [db prepare {insert into person values(:id, :name)}]
    # It is important -> need to setup type
    $statement paramtype id integer
    $statement paramtype name varchar    
    
    set myparams [dict create id 1 name Leo]
    $statement execute $myparams    
    
    set id 2
    set name Mary    
    $statement execute
    $statement close

    set statement [db prepare {SELECT * FROM person}]

    $statement foreach row {
         if {[catch {set id [dict get $row ID]}]} {
            puts "ID:"
         } else {
            puts "ID: $id"
         }
         
         if {[catch {set name [dict get $row NAME]}]} {
            puts "NAME:"
         } else {
            puts "NAME: $name"
         }        
    }

    $statement close

    set statement [db prepare {drop table person}]
    $statement execute
    $statement close

    db close

## Example: H2 database

[H2](http://www.h2database.com/html/main.html) is a relational database management
system written in Java. It can be embedded in Java applications or run in the
client-server mode.

Below is an exmaple:

    package require tdbc::jdbc

    set className    {org.h2.Driver}
    set url          jdbc:h2:c:/temp/test
    set username     "SA"
    set password     "SA"

    tdbc::jdbc::connection create db $className $url $username $password -readonly 0

    set statement [db prepare {CREATE TABLE if not exists userdata ( user varchar(50) not null)}]
    $statement execute
    $statement close

    set statement [db prepare {INSERT INTO userdata ( user ) VALUES ( 'Cameron' )}]
    $statement execute
    $statement close

    set statement [db prepare {INSERT INTO userdata ( user ) VALUES ( 'Bahamut' )}]
    $statement execute
    $statement close

    set statement [db prepare {INSERT INTO userdata ( user ) VALUES ( 'Thrall' )}]
    $statement execute
    $statement close

    set statement [db prepare {INSERT INTO userdata ( user ) VALUES ( 'Mandora' )}]
    $statement execute
    $statement close

    set statement [db prepare {UPDATE userdata SET user = 'Mandorala' where user = 'Mandora'}]
    $statement execute
    $statement close

    set statement [db prepare {SELECT * FROM userdata}]

    $statement foreach row {
         if {[catch {set user [dict get $row USER]}] == 0} {
            puts "User: $user"
         }        
    }

    $statement close

    set statement [db prepare {drop table if exists userdata}]
    $statement execute
    $statement close

    db close

## Example: Apache Derby

[Apache Derby](https://db.apache.org/derby/) is developed as an open source
project under the Apache 2.0 license. Oracle distributes the same binaries
under the name `Java DB`.

Below is an exmaple:

    package require tdbc::jdbc

    set className    {org.apache.derby.jdbc.EmbeddedDriver}
    set url          {jdbc:derby:sample;create=true}
    set username     ""
    set password     ""

    tdbc::jdbc::connection create db $className $url $username $password -readonly 0

    set createTableCheck {
        set in_result {}
        set statement [db prepare {select TABLENAME from SYS.SYSTABLES where TABLENAME = 'PERSON'}]
        $statement foreach row {
            if {[catch {set in_result [dict get $row TABLENAME]}]} {
                set in_result ""
            }
        }
        $statement close

        if {[string length $in_result] == 0} {
            set statement [db prepare {create table person (id integer not null, name varchar(40))}]
            catch {$statement execute}
            $statement close
        }

        unset in_result
    }

    # Use transaction method to do create table check
    db transaction $createTableCheck

    set statement [db prepare {insert into person values(:id, :name)}]
    # It is important -> need to setup type
    $statement paramtype id integer
    $statement paramtype name varchar    

    set myparams [dict create id 1 name Duncan]
    $statement execute $myparams    

    set myparams [dict create id 2 name Mario]  
    $statement execute $myparams  
    $statement close

    set statement [db prepare {SELECT * FROM person}]

    $statement foreach row {
         if {[catch {set id [dict get $row ID]}]} {
            puts "ID:"
         } else {
            puts "ID: $id"
         }

         if {[catch {set name [dict get $row NAME]}]} {
            puts "NAME:"
         } else {
            puts "NAME: $name"
         }        
    }

    $statement close

    set statement [db prepare {drop table person}]
    $statement execute
    $statement close

    db close

## Example: PostgreSQL

Download JDBC driver from [PostgreSQL JDBC Driver](https://jdbc.postgresql.org/index.html). Below is a simple exmaple:

    package require tdbc::jdbc

    set className    {org.postgresql.Driver}
    set url          jdbc:postgresql://localhost:5432/danilo
    set username     danilo
    set password     danilo

    tdbc::jdbc::connection create db $className $url $username $password -readonly 0

    set statement [db prepare {select extname, extversion from pg_extension}]
    puts "List extension name and version:"
    $statement foreach row {
        puts "[dict get $row extname] - [dict get $row extversion]"
    }

    $statement close

    db close

## Example: MonetDB

This example is only to test MonetDB
[JDBC driver](https://www.monetdb.org/Documentation/Manuals/SQLreference/Programming/JDBC).

Below is an exmaple:

    package require tdbc::jdbc

    set className    {nl.cwi.monetdb.jdbc.MonetDriver}
    set url          jdbc:monetdb://localhost:50000/demo
    set username     monetdb
    set password     monetdb

    tdbc::jdbc::connection create db $className $url $username $password

    set script {
        set in_result {}
        set statement [db prepare {select name from sys.tables where name = 'power'}]
        $statement foreach row {
            set in_result [dict get $row name]
        }
        $statement close
        
        if {[string length $in_result] > 0} {
            set statement [db prepare {drop table power}]
            catch {$statement execute}
            $statement close
        }
        
        unset in_result
    }

    # Use transaction method to drop table
    db transaction $script

    set statement [db prepare \
        {create table power (name varchar(40) not null, number double)}]
    $statement execute
    $statement close

    set statement [db prepare {insert into power values(:name, :number)}]
    # It is important -> need to setup type
    $statement paramtype name varchar
    $statement paramtype number double

    set name Mercy 
    set number 100.01
    $statement execute

    set name Jerry 
    set number 90.99
    $statement execute
    $statement close

    set statement [db prepare {SELECT * FROM power}]

    $statement foreach row {
        puts [dict get $row name]
        puts [dict get $row number]
    }

    $statement close
    db close

## Example: SQLite

SQLite already have very good [Tcl interface](https://www.sqlite.org/tclsqlite.html) and [TDBC driver](http://www.tcl.tk/man/tcl8.6/TdbcsqliteCmd/tdbc_sqlite3.htm). This example is only to test [SQLite JDBC driver](https://bitbucket.org/xerial/sqlite-jdbc).

Below is an exmaple:

    package require tdbc::jdbc

    set className    {org.sqlite.JDBC}
    set url          jdbc:sqlite:sample.db
    set username     ""
    set password     ""

    if {[catch {tdbc::jdbc::connection create db $className $url $username $password -readonly 0} errMsg]} {
        puts $errMsg
        exit
    }

    set statement [db prepare {drop table if exists person}]
    $statement execute
    $statement close

    set statement [db prepare {create table person (id integer not null, name string)}]
    $statement execute
    $statement close

    set statement [db prepare {insert into person values(:id, :name)}]
    # It is important -> need to setup type
    $statement paramtype id integer
    $statement paramtype name varchar    

    set myparams [dict create id 1 name Leo]
    $statement execute $myparams    

    set id 2
    set name Mary    
    $statement execute
    $statement close

    set statement [db prepare {SELECT * FROM person}]

    $statement foreach row {
         if {[catch {set id [dict get $row id]}]} {
            puts "ID:"
         } else {
            puts "ID: $id"
         }

         if {[catch {set name [dict get $row name]}]} {
            puts "NAME:"
         } else {
            puts "NAME: $name"
         }        
    }

    $statement close

    db close

## Example: TiDB

TiDB is a distributed NewSQL database compatible with MySQL protocol.
I download [MySQL JDBC driver](https://dev.mysql.com/downloads/connector/j/) to test TiDB.

    package require tdbc::jdbc

    set className    {com.mysql.jdbc.Driver}
    set url          jdbc:mysql://localhost:4000/test?useSSL=true
    set username     "root"
    set password     ""

    tdbc::jdbc::connection create db $className $url $username $password

    set statement [db prepare \
        {create table contact (name varchar(20) not null  UNIQUE, 
        email varchar(40) not null, primary key(name))}]
    $statement execute
    $statement close

    set statement [db prepare {insert into contact values(:name, :email)}]
    $statement paramtype name varchar
    $statement paramtype email varchar

    set name danilo
    set email danilo@test.com
    $statement execute

    set name scott
    set email scott@test.com
    $statement execute

    set myparams [dict create name arthur email arthur@example.com]
    $statement execute $myparams
    $statement close

    set statement [db prepare {SELECT * FROM contact}]
    $statement foreach row {
        puts [dict get $row name]
        puts [dict get $row email]
    }
    $statement close

    set statement [db prepare {DROP TABLE  contact}]
    $statement execute
    $statement close
    db close

## Example: CUBRID

I create a `demo` database to test CUBRID 10.0
[JDBC Driver](http://www.cubrid.org/manual/10_0/en/api/jdbc.html).

Below is an exmaple:

    package require tdbc::jdbc

    set className    {cubrid.jdbc.driver.CUBRIDDriver}
    set url          jdbc:cubrid:127.0.0.1:33000:demo:public::
    set username     ""
    set password     ""

    tdbc::jdbc::connection create db $className $url $username $password

    set statement [db prepare {create table if not exists person (id integer not null, name varchar(40))}]
    $statement execute
    $statement close

    set statement [db prepare {insert into person values(:id, :name)}]
    # It is important -> need to setup type
    $statement paramtype id integer
    $statement paramtype name varchar

    set myparams [dict create id 1 name Leo]
    $statement execute $myparams

    set id 2
    set name Mary
    $statement execute
    $statement close

    set statement [db prepare {SELECT * FROM person}]

    $statement foreach row {
        if {[catch {set id [dict get $row id]}]} {
            puts "ID:"
        } else {
            puts "ID: $id"
        }

        if {[catch {set name [dict get $row name]}]} {
            puts "NAME:"
        } else {
            puts "NAME: $name"
        }
    }

    $statement close

    set statement [db prepare {drop table person}]
    $statement execute
    $statement close

    db close

## Example: Apache Phoenix

[Apache Phoenix](https://phoenix.apache.org/) offers a SQL skin on HBase.
Phoenix is implemented as a JDBC driver.

I just test Apache HBase 1.2.3 and Apache Phoenix 4.8.0 on Localhost. And I use
`setUsePrepared` method (setup flag to 0) to use Statement to replace
prepareStatement.

    package require tdbc::jdbc

    set className    {org.apache.phoenix.jdbc.PhoenixDriver}
    set url          jdbc:phoenix:localhost
    set username     ""
    set password     ""

    # Just connect to localhost HBase
    tdbc::jdbc::connection create db $className $url $username $password -isolation readcommitted

    # Only for test: use Statement to replace prepareStatement
    db setUsePrepared 0

    set statement [db prepare {CREATE TABLE IF NOT EXISTS STOCK_SYMBOL
                     (SYMBOL VARCHAR NOT NULL PRIMARY KEY, COMPANY VARCHAR)}]
    $statement execute
    $statement close

    set statement [db prepare {UPSERT INTO STOCK_SYMBOL (SYMBOL, COMPANY) 
                      VALUES ('CRM','SalesForce.com')}]
    $statement execute
    $statement close

    set statement [db prepare {UPSERT INTO STOCK_SYMBOL (SYMBOL, COMPANY) 
                      VALUES ('MSFT','Microsoft')}]
    $statement execute
    $statement close

    set statement [db prepare {UPSERT INTO STOCK_SYMBOL (SYMBOL, COMPANY) 
                      VALUES ('FB','Facebook')}]
    $statement execute
    $statement close

    # Apache Phoenix needs invoke commit method to update record
    db commit

    set statement [db prepare {SELECT * FROM STOCK_SYMBOL}]
    $statement foreach row {
        if {[catch {set symbol [dict get $row SYMBOL]}] == 0} {
            puts "SYMBOL: $symbol"
            if {[catch {set company [dict get $row COMPANY]}] == 0} {
                puts "COMPANY: $company"
            }
        }
    }

    $statement close

    set statement [db prepare {drop table if exists STOCK_SYMBOL}]
    $statement execute
    $statement close

    db close

## Example: Apache Drill

[Apache Drill](https://drill.apache.org/) is a low-latency distributed query
engine for large-scale datasets, including structured and semi-structured/nested
data.

I just test Apache Drill JDBC driver in distributed mode. And I use
`setUsePrepared` method (setup flag to 0) to use Statement to replace
prepareStatement.

I enable [User Authentication](https://drill.apache.org/docs/configuring-user-authentication/)
to test Apache Drill JDBC driver. So if you use TDBCJDBC to connect Apache Drill,
please remember to update url, username and password.

Apache Drill provides sample data, try it:

    package require tdbc::jdbc

    set className    {org.apache.drill.jdbc.Driver}
    set url          jdbc:drill:zk=192.168.2.103:2181/drill/drillbits1
    set username     "danilo"
    set password     "danilo"

    tdbc::jdbc::connection create db $className $url $username $password

    # Only for test: use Statement to replace prepareStatement
    db setUsePrepared 0

    set statement [db prepare {SELECT * FROM cp.`employee.json` LIMIT 5}]
    $statement foreach row {
        puts "=================="
        foreach {key value} $row {
            puts "$key - $value"
        }
    }

    $statement close

    db close

