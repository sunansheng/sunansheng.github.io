---
layout: post
title: Oracle 数据库的启动与关闭
categories: [Oracle]
tags: 启动关闭
---

## 数据库的启动

数据库的启动极其简单，只需要以SYSDBA/SYSOPER身份登录，输入一条startup命令即可启动数据库。然而在这条命令之后，Oracle需要执行一系列复杂的操作，深入理解这些操作不仅有助于了解Oracle数据库的运行机制，还可以在故障发生时帮助用户快速的定位问题的根源所在，所以接下来将分析一下数据库的启动过程。

Oracle 数据库的启动主要包含 3 个过程：
- 启动数据库到 NOMOUNT状态；
- 启动数据库到 MOUNT 状态；
- 启动数据库到 OPEN 状态。

![](/images/posts/20180620155337.jpg)

下面逐个来看看以上各个步骤的具体过程以及含义。 

### 1. 启动数据库到NOMOUNT状态的过程 

在启动的第一步，Oracle首先寻找参数文件(pfile/spfile)，然后根据参数文件中的设置(如内存分配等设置)，创建实例(Instance)，分配内存，启动后台进程。**NOMOUNT的过程也就是启动数据库实例的过程。**

####  1. 实例以及进程的创建 

以下是正常情况下启动数据库到 NOMOUNT状态的过程： 

```sql
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

观察告警日志文件(alert_<ORACLE_SID>.log，show parameter dump获取存储位置)，可以看到这一阶段的启动过程：读取参数文件，应用参数启动实例。所有在参数文件中定义的非缺省参数都会记录在告警日志文件中，以下是这一过程的日志摘要示例：

```shell
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

在Oracle 11g中，这部分信息有了进一步的增强，输出中不仅包含了OSID，而且每个后台进程的启动都有单独的时间标记(时间标记可以帮助用户判断每个后台进程启动时所消耗的时间，从而辅助进行问题诊断)。


### 2. V$PROCESS视图 

通过数据库中的 v$process 视图，可以找到对应于操作系统的每个进程信息： 

```sql
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
注意以上输出，pid=1的进程是一个PSEUDO进程，这个进程被认为是初始化数据库的进程，启动其他进程之前即被占用，并在数据库中一直存在。v$process的查询输出中，SPID列代表的就是操作系统上的进程号，通过SPID可以将进程从操作系统到数据库关联起来。

如果在操作系统上发现某个进程表现异常(如占用很高的CPU资源)，那么通过操作系统上的PID和V$PROCESS视图中的SPID关联，就可以找到这个OS上的进程在数据库内部的化身，从而可以进行进一步的跟踪诊断。

注意这里的ADDR字段代表的是进程的地址，进程的状态等信息在内存中记录，这个ADDR记录的正是这样的内存地址信息。ADDR在数据库中(甚至是在所有软件中)是非常重要的，虽然通常并不会用到，但是深入理解这些知识将有助于更好地了解Oracle数据库。

进程的地址(AddressofProcess)被缩写为PADDR，在V$SESSION视图中记录的PADDR就是V$PROCESS.ADDR的进一步延伸，通过两者关联，可以向数据库进一步深入。

### 3. 参数文件的选择

从Oracle9i开始，spfile被引入Oracle数据库，**Oracle首选spfile<ORACLE_SID>.ora文件作为启动参数文件；如果该文件不存在，Oracle选择spfile.ora文件；如果前两者都不存在，Oracle将会选择init<ORACLE_SID>.ora文件；如果以上3个文件都不存在，Oracle将无法创建和启动Instance。**Oracle在启动过程中，会在特定的路径中寻找参数文件，在UNIX/Linux下的路径为$ORACLE_HOME/dbs目录，在Windows上的路径为$ORACLE_HOME\database目录。

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

    [oracle@jumper dbs]$ export ORACLE _ SID=julia
    SQL> ! echo "db_ name=julia" > /opt/oracle/product/9.2.0/dbs/initjulia.ora 
    SQL> startup nomount; 
    ORACLE instance started. 
     
    Total System Global Area   97588504 bytes 
    Fixed Size                   451864 bytes 
    Variable Size              46137344 bytes 
    Database Buffers           50331648   bytes 
    Redo Buffers                 667648   bytes 

这样，通过以上步骤就以最少的参数需求启动了Oracle实例。