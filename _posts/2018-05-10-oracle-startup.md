---
layout: post
title: Oracle 数据库的启动详解
categories: [Oracle]
tags: 启动
---

## 数据库的启动

数据库的启动极其简单，只需要以SYSDBA/SYSOPER身份登录，输入一条startup命令即可启动数据库。然而在这条命令之后，Oracle需要执行一系列复杂的操作，深入理解这些操作不仅有助于了解Oracle数据库的运行机制，还可以在故障发生时帮助用户快速的定位问题的根源所在，所以接下来将分析一下数据库的启动过程。

Oracle 数据库的启动主要包含 3 个过程：
- 启动数据库到 NOMOUNT 状态；
- 启动数据库到 MOUNT 状态；
- 启动数据库到 OPEN 状态。

![](/images/posts/20180620155337.jpg)

下面逐个来看看以上各个步骤的具体过程以及含义。 

## 1. 启动数据库到NOMOUNT状态的过程 

在启动的第一步，Oracle首先寻找参数文件(pfile/spfile)，然后根据参数文件中的设置(如内存分配等设置)，创建实例(Instance)，分配内存，启动后台进程。**NOMOUNT的过程也就是启动数据库实例的过程。**

####  1. 实例以及进程的创建 

以下是正常情况下启动数据库到 NOMOUNT状态的过程： 

```
[oracle@dbtest ~]$ sqlplus / as sysdba

SQL*Plus: Release 11.2.0.1.0 Production on Wed May 4 10:09:35 2016
Copyright (c) 1982, 2009, Oracle.  All rights reserved.
Connected to an idle instance.

SQL> startup nomount;
ORACLE instance started.

Total System Global Area 1152450560 bytes
Fixed Size                  2212696 bytes
Variable Size             922750120 bytes
Database Buffers          218103808 bytes
Redo Buffers                9383936 bytes
SQL> 
```
注意这里，Oracle根据参数文件的内容，创建了Instance，分配了相应的内存区域，启动了相应的后台进程。SGA的分配信息从以上输出中可以看到。

观察告警日志文件(alert_\<ORACLE_SID\>.log，show parameter dump获取存储位置)，可以看到这一阶段的启动过程：读取参数文件，应用参数启动实例。所有在参数文件中定义的非缺省参数都会记录在告警日志文件中，以下是这一过程的日志摘要示例：

```
Starting up:
Oracle Database 11g Enterprise Edition Release 11.2.0.1.0 - 64bit Production
With the Partitioning, OLAP, Data Mining and Real Application Testing options.
Using parameter settings in server-side spfile /u01/app/oracle/product/11.2.0/db_1/dbs/spfileorcl.ora
System parameters with non-default values:
  processes                = 150
  sga_target               = 176M
  memory_target            = 1104M
  memory_max_target        = 1104M
  control_files            = "/u01/app/oracle/oradata/orcl/control01.ctl"
  control_files            = "/u01/app/oracle/flash_recovery_area/orcl/control02.ctl"
  db_block_size            = 8192
  compatible               = "11.2.0.0.0"
  db_recovery_file_dest    = "/u01/app/oracle/flash_recovery_area"
  db_recovery_file_dest_size= 3882M
  undo_tablespace          = "UNDOTBS1"
  remote_login_passwordfile= "EXCLUSIVE"
  db_domain                = "oracle.com"
  global_names             = FALSE
  dispatchers              = "(PROTOCOL=TCP) (SERVICE=orclXDB)"
  shared_servers           = 5
  audit_file_dest          = "/u01/app/oracle/admin/orcl/adump"
  audit_trail              = "DB"
  db_name                  = "orcl"
  open_cursors             = 300
  diagnostic_dest          = "/u01/app/oracle"
Wed May 04 10:09:56 2016
PMON started with pid=2, OS id=9908 
Wed May 04 10:09:56 2016
VKTM started with pid=3, OS id=9912 at elevated priority
VKTM running at (10)millisec precision with DBRM quantum (100)ms
Wed May 04 10:09:56 2016
GEN0 started with pid=4, OS id=9918 
Wed May 04 10:09:56 2016
DIAG started with pid=5, OS id=9922 
Wed May 04 10:09:56 2016
DBRM started with pid=6, OS id=9926 
......
Wed May 04 10:09:57 2016
MMON started with pid=15, OS id=9962 
Wed May 04 10:09:57 2016
MMNL started with pid=16, OS id=9966 
starting up 1 dispatcher(s) for network address '(ADDRESS=(PARTIAL=YES)(PROTOCOL=TCP))'...
starting up 5 shared server(s) ...
ORACLE_BASE from environment = /u01/app/oracle
```
应用参数创建实例之后，后台进程依次启动，注意以下输出中包含了PID以及OS ID两个信息，PID代表该进程在数据库内部的标识符编号，而OS ID则代表该进程在操作系统上的进程编号：

	DBRM started with pid=6, OS id=9926 

在Oracle 11g中，这部分信息有了进一步的增强，输出中不仅包含了OS ID，而且每个后台进程的启动都有单独的时间标记(时间标记可以帮助用户判断每个后台进程启动时所消耗的时间，从而辅助进行问题诊断)。


### 2. V\$PROCESS视图 



通过数据库中的 v\$process 视图，可以找到对应于操作系统的每个进程信息： 

```
SQL> select addr,pid,spid,username,program from v$process;  

ADDR                    PID SPID                     USERNAME        PROGRAM
---------------- ---------- ------------------------ --------------- ------------------------------------------------
00000000A44C6960          1                                          PSEUDO
00000000A44C79A0          2 9908                     oracle          oracle@dbtest.oracle.com (PMON)
00000000A44C89E0          3 9912                     oracle          oracle@dbtest.oracle.com (VKTM)
00000000A44C9A20          4 9918                     oracle          oracle@dbtest.oracle.com (GEN0)
00000000A44CAA60          5 9922                     oracle          oracle@dbtest.oracle.com (DIAG)
00000000A44CBAA0          6 9926                     oracle          oracle@dbtest.oracle.com (DBRM)
00000000A44CCAE0          7 9930                     oracle          oracle@dbtest.oracle.com (PSP0)
00000000A44CDB20          8 9934                     oracle          oracle@dbtest.oracle.com (DIA0)
00000000A44CEB60          9 9938                     oracle          oracle@dbtest.oracle.com (MMAN)
00000000A44CFBA0         10 9942                     oracle          oracle@dbtest.oracle.com (DBW0)
00000000A44D0BE0         11 9946                     oracle          oracle@dbtest.oracle.com (LGWR)
00000000A44D1C20         12 9950                     oracle          oracle@dbtest.oracle.com (CKPT)
00000000A44D2C60         13 9954                     oracle          oracle@dbtest.oracle.com (SMON)
00000000A44D3CA0         14 9958                     oracle          oracle@dbtest.oracle.com (RECO)
```
注意以上输出，pid=1的进程是一个PSEUDO进程，这个进程被认为是初始化数据库的进程，启动其他进程之前即被占用，并在数据库中一直存在。v\\$process的查询输出中，SPID列代表的就是操作系统上的进程号，通过SPID可以将进程从操作系统到数据库关联起来。

如果在操作系统上发现某个进程表现异常(如占用很高的CPU资源)，那么通过操作系统上的PID和V\\$PROCESS视图中的SPID关联，就可以找到这个OS上的进程在数据库内部的化身，从而可以进行进一步的跟踪诊断。

注意这里的ADDR字段代表的是进程的地址，进程的状态等信息在内存中记录，这个ADDR记录的正是这样的内存地址信息。ADDR在数据库中(甚至是在所有软件中)是非常重要的，虽然通常并不会用到，但是深入理解这些知识将有助于更好地了解Oracle数据库。

进程的地址(Address of Process)被缩写为PADDR，在v\\$session视图中记录的PADDR就是V\\$PROCESS.ADDR
的进一步延伸，通过两者关联，可以向数据库进一步深入。


### 3. 参数文件的选择

从Oracle9i开始，spfile被引入Oracle数据库，
Oracle首选**spfile\<ORACLE_SID\>.ora**文件作为启动参数文件；如果该文件不存在，Oracle选择**spfile.ora**文件；如果前两者都不存在，Oracle将会选择**init\<ORACLE_SID\>.ora**文件；如果以上3个文件都不存在，Oracle将无法创建和启动Instance。Oracle在启动过程中，会在特定的路径中寻找参数文件，在UNIX/Linux下的路径为\\$ORACLE_HOME/dbs目录，在Windows上的路径为\$ORACLE_HOME\database目录。

可以在SQL*PLUS中通过show parameter spfile命令来检查数据库是否使用了spfile文件，如果value不为Null，则数据库使用了spfile文件：

```sql
SQL> show parameter spfile;
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
spfile                               string      /u01/dev/db/tech_st/11.2.0/dbs/spfiledev.ora
```

### 4. 实例启动最小参数需求 

在参数文件中，通常需要最少的参数是DB_NAME，设置了这个参数之后，数据库实例就可以启动，来看一个简单的测试。

可以随意命名一个ORACLE_SID,然后尝试启动到NOMOUNT状态：

    [oracle@jumper dbs]$ export ORACLE_SID=julia
    SQL> ! echo "db_ name=julia" > /opt/oracle/product/9.2.0/dbs/initjulia.ora 
    SQL> startup nomount; 
    ORACLE instance started. 
     
    Total System Global Area   97588504 bytes 
    Fixed Size                   451864 bytes 
    Variable Size              46137344 bytes 
    Database Buffers           50331648   bytes 
    Redo Buffers                 667648   bytes 

这样，通过以上步骤就以最少的参数需求启动了Oracle实例。

**在创建数据库时，如果在启动NOMOUNT这一步骤就出现问题，那么通常可能是系统配置(如内核参数等)存在问题，用户需要检查是否分配了足够的系统资源等。**

## 2. 启动数据库到MOUNT 状态 

在创建数据库时，如果在这一步骤就出现问题，那么通常可能是系统配置(如内核参数等)存在问题，用户需要检查是否分配了足够的系统资源等。

### 2.1 控制文件的定位 

在Oracle 10g之前，通常Oracle缺省的会创建3个控制文件，这3个控制文件的内容完全一致，是Oracle为了安全而采用的镜像手段，在生产环境中，通常应该将控制文件存放在不同的物理硬盘上，避免因为介质故障而同时损坏3个控制文件。从Oracle 10g开始，如果设置了闪回恢复区(Flashback Recovery Area，通常闪回区和数据区位于不同硬盘存储)，则Oracle缺省就会将控制文件分布到不同的磁盘组，至此Oracle才算完成了控制文件的真正镜像安全保护：

控制文件信息在参数文件中记录类似如下所示： 

	*.control_files='/u01/app/oracle/oradata/orcl/control01.ctl','/u01/app/oracle/flash_recovery_area/orcl/control02.ctl'

在NOMOUNT状态，可以查询v\\$parameter视图，获得控制文件信息，这部分信息来自启动的参数文件；当数据库MOUNT之后，可以查询v\\$controlfile视图获得关于控制文件的信息，此时，这部分信息来自控制文件：

```shell
SQL> startup nomount
ORACLE instance started.

Total System Global Area 1152450560 bytes
Fixed Size                  2212696 bytes
Variable Size             922750120 bytes
Database Buffers          218103808 bytes
Redo Buffers                9383936 bytes
SQL> show parameter control_files

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
control_file_record_keep_time        integer     7
control_files                        string      /u01/app/oracle/oradata/orcl/c
                                                 ontrol01.ctl, /u01/app/oracle/
                                                 flash_recovery_area/orcl/contr
                                                 ol02.ctl


SQL> alter database mount;
SQL> select  * from v$controlfile;

STATUS  NAME                                                                             IS_RECOVERY_DEST_FILE BLOCK_SIZE FILE_SIZE_BLKS
------- -------------------------------------------------------------------------------- --------------------- ---------- --------------
        /u01/app/oracle/oradata/orcl/control01.ctl                                       NO                         16384            594
        /u01/app/oracle/flash_recovery_area/orcl/control02.ctl                           NO                         16384            594
```

在MOUNT数据库的过程中，Oracle需要找到控制文件，锁定控制文件。如果控制文件全部丢失此时就会报出如下错误：

	ORA -00205: error in identifying controlfile, check alert log for more info  
	
因为Oracle的3个(缺省的)控制文件内容完全相同，如果只是损失了其中1个或2个，可以复制完好的控制文件，并更改为相应的名称，就可以启动数据库；如果丢失了所有的控制文件，那么就需要恢复或重建控制文件来打开数据库。

### 2.2 数据文件的存在性判断 

在启动了实例之后，实际上数据库的后台进程已经运行，那么当进一步的MOUNT数据库之后，后台进程就可以根据控制文件中记录的数据文件信息来验证数据文件是否存在，如果数据文件不存在，则后台进程将在告警日志文件中记录文件缺失信息，并且在动态视图中记录这些信息。

对以下数据库进行一个简单测试： 

```
SQL> select name from v$datafile;

NAME
--------------------------------------------------------------------------------
/u01/app/oracle/oradata/orcl/system01.dbf
/u01/app/oracle/oradata/orcl/sysaux01.dbf
/u01/app/oracle/oradata/orcl/undotbs01.dbf
/u01/app/oracle/oradata/orcl/users01.dbf
/u01/app/oracle/oradata/orcl/example01.dbf
```

通过以下步骤，移除一个测试文件： 

```shell
SQL> shutdown immediate;
ORA-01109: database not open
Database dismounted.
ORACLE instance shut down.

SQL> !mv /u01/app/oracle/oradata/orcl/example01.dbf /u01/app/oracle/oradata/orcl/example01.dbf.bak

SQL>  startup mount;
ORACLE instance started.
Total System Global Area 1152450560 bytes
Fixed Size                  2212696 bytes
Variable Size             922750120 bytes
Database Buffers          218103808 bytes
Redo Buffers                9383936 bytes
Database mounted.
SQL> 
```

此时检查告警日志文件，则可以发现数据文件的缺失信息： 


	[oracle@dbtest trace]$ tail -n 20 alert_orcl.log
	CKPT started with pid=12, OS id=12302 
	Thu May 05 02:53:02 2016
	SMON started with pid=13, OS id=12306 
	Thu May 05 02:53:02 2016
	RECO started with pid=14, OS id=12310 
	Thu May 05 02:53:02 2016
	MMON started with pid=15, OS id=12314 
	starting up 1 dispatcher(s) for network address '(ADDRESS=(PARTIAL=YES)(PROTOCOL=TCP))'...
	Thu May 05 02:53:02 2016
	MMNL started with pid=16, OS id=12318 
	starting up 5 shared server(s) ...
	ORACLE_BASE from environment = /u01/app/oracle
	Thu May 05 02:53:03 2016
	ALTER DATABASE   MOUNT
	Successful mount of redo thread 1, with mount id 1438763279
	Database mounted in Exclusive Mode
	Lost write protection disabled
	Completed: ALTER DATABASE   MOUNT
	Thu May 05 02:54:28 2016
	Checker run found 1 new persistent data failures  --报错

此时查询数据的动态视图v$recover_file，可以发现数据库记录了FILE NOT FOUND的错误信息：

```
SQL> SELECT * FROM  v$recover_file;

     FILE# ONLINE  ONLINE_STATUS ERROR                 CHANGE# TIME
---------- ------- ------------- ------------------ ---------- -----------
         5 ONLINE  ONLINE        FILE NOT FOUND              0 
```
	
### 2.3 口令文件的作用 

从Oracle 10g开始，当口令文件丢失后，在启动过程中，Oracle将不再提示错误，只是和口令文件相关的部分功能将无法使用。比如之后进行SYSDBA的授权或者尝试远程通过SYSDBA身份登录都会出现错误：

	SQL> connect sys/oracle@eygle as sysdba 
	ERROR: 
	ORA -01031: insufficient privileges 
	Warning: You are no longer connected to ORACLE. 
	
以下是丢失口令文件的授权示例，系统将提示无法找到口令文件的错误： 

	SQL> grant sysdba  to test;  
	grant sysdba to test 
	*  
	ERROR at line 1: 
	ORA -01994: GRANT failed: password file missing or disabled 

数据库里具有SYSDBA/SYSOPER 权限的用户可以通过v$pwfile_users视图查询得到。 

```
SQL> SELECT * FROM  v$pwfile_users;

USERNAME                       SYSDBA SYSOPER SYSASM
------------------------------ ------ ------- ------
SYS                            TRUE   TRUE    FALSE
```

## 3. 启动数据库OPEN阶段 

由于控制文件中记录了数据库中数据文件、日志文件的位置信息，检查点信息等重要信息，在数据库的OPEN阶段，Oracle将根据控制文件中记录的这些信息找到这些文件，然后进行检查点及完整性检查。如果不存在问题就可以启动数据库，如果存在不一致或文件丢失则需要进行恢复。

在数据库 OPEN 的过程中，Oracle进行的检查中包括以下两项：

第一次检查数据文件头中的检查点计数(Checkpoint CNT)是否和控制文件中的检查点计数(Checkpoint CNT)一致。此步骤检查用以确认数据文件是来自同一版本，而不是从备份中恢复而来(因为Checkpoint CNT不会被冻结，会一直被修改)。

如果检查点计数检查通过，则数据库进行第二次检查。第二次检查数据文件头的开始SCN和控制文件中记录的该文件的结束SCN是否一致，如果控制文件中记录的结束SCN等于数据文件头的开始SCN，则不需要对那个文件进行恢复。

如果数据库中的某个文件丢失，在MOUNT数据库时Oracle会在后台将文件丢失信息记录在告警日志文件中，但是并不会在前台给出提示；而在OPEN阶段，如果数据库无法锁定该文件，则会在前台发出错误警告，数据库将停止启动.