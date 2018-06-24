---
layout: post
title: Oracle 数据库备份与恢复
categories: [Oracle]
tags: 备份恢复
---

## 1. 备份方法

Oracle 的备份按照备份方式的不同可以分为两类：逻辑备份和物理备份。

### 1.1 逻辑备份

逻辑备份指通过逻辑导出对数据进行备份，逻辑备份的数据只能基于备份时刻进行数据转储，所以恢复时也只能恢复到备份时保存的数据。对于故障点和备份点之间的数据，逻辑备份是无能为力的，逻辑备份适合备份那些很少变化的数据表，当这些数据因误操作被损坏时，可以通过逻辑备份进行快速恢复。如果通过逻辑备份进行全库恢复，通常需要重建数据库，导入备份数据来完成，对于可用性要求很高的数据库，这种恢复的时间太长，通常不被采用。由于逻辑备份具有平台无关性，所以更为常见的是，逻辑备份被作为一个数据迁移及移动的主要手段。

### 1.2 物理备份

物理备份是指通过物理文件拷贝的方式对数据库进行备份，物理备份又可以分为**冷备份**和**热备份**。

冷备份是指对数据库进行关闭后的拷贝备份，这样的备份具有一致和完整的时间点数据，恢复时只需要恢复所有文件就可以启动数据库；

在生产系统中最为常见的备份方式是热备份，进行热备份的数据库需要运行在**归档模式**，热备份时不需要关闭数据库，从而能够保证系统的持续运行，在进行恢复时，通过备份的数据文件及归档日志等文件，数据库可以进行完全恢复，恢复可以一直进行到最后一个归档日志，如果联机日志存在，则恢复可以继续，实现无数据损失的完全恢复。当然，如果是为了恢复某些用户错误，热备份的恢复完全可以在某一个时间点上停止恢复，也就是不完全恢复。

## 2. 完全恢复与不完全恢复

做好了备份之后，在故障时就需要通过备份来进行恢复。

Oracle数据库有一个重要的组成结构：重做日志(Redo Log)。重做日志用来记录数据库操作的必要信息，以便在发生故障时能够通过事务重演来恢复数据。Oracle的数据恢复就依赖于重做日志文件(Redo Log File)以及由其衍生的归档日志文件(Archived Redo Log File)。

针对不同的故障情况，Oracle可以通过不同的方式进行数据恢复。根据不同的故障情况，热备份的恢复可以分为**完全恢复**和**不完全恢复**两类。

如果在恢复时我们拥有足够的归档日志(Archived RedoLog)和在线重做日志(Online RedoLog)，那么通过恢复一个全备份，应用归档日志和重做日志，最终数据库就可以实现完全恢复，恢复后的数据库不会有任何数据损失。

如果恢复在应用日志完成之前停止，则进行的就是一次不完全恢复。逐渐应用日志向前恢复的过程称为前滚(Roll Forward)，前滚的过程实际上就是应用日志重演事务的过程(Replay transactions)，完成前滚后，数据文件将包含提交和未提交的数据，然后需要应用回滚数据，将未提交的事务回滚，这个过程称为rolling back或transaction recovery。

通常，完全恢复应用于那些由于硬件故障导致的数据库损失，在这种情况下需要最大可能的恢复数据；不完全恢复通常用于恢复用户错误，误操作Drop掉一个业务数据表，那么恢复需要执行到删除之前停止，这样就可以找回被误删除的数据表，此时执行的就是一次不完全恢复。

很多情况下进行的是不完全恢复，选择不完全恢复的可能原因很多，最常见的情况如下：

- 归档日志丢失。由于某个归档日志丢失，恢复只能执行的过去的某个时间点。

- 在线日志文件损坏。在线的日志文件损坏，则恢复只能停止在损坏的日志之前。

- 用户错误操作。用户错误地drop/truncate了数据表，恢复必须在这些动作发出前停止，以完成数据恢复。

不完全恢复主要有 4 种类型：基于时间的恢复（Time-based Recovery）、基于放弃的恢复（Cancel-based Recovery）、基于改变的恢复（Change-based Recovery）和基于日志序列的恢复（Logsequence recovery）。

## 3. 数据库的运行模式

归档模式(Archive log)和非归档模式是Oracle数据库的两种运行方式，所谓归档是指对历史的RedoLog日志文件进行归档保存。Oracle依赖Redo LogFile来进行故障恢复，也就是重做，在非归档模式下，Redo LogFile以覆盖的方式循环使用，在归档模式下，日志文件被覆盖之前必须已经被复制归档，保留的归档日志将为Oracle提供强大的故障恢复能力。

在命令行，可以通过命令 archive log list 获取当前数据库的归档状态，例如：

```sql
SQL> archive log list;
Database log mode              Archive Mode
Automatic archival             Enabled
Archive destination            USE_DB_RECOVERY_FILE_DEST
Oldest online log sequence     771
Next log sequence to archive   773
Current log sequence           773
```

运行在归档模式下，数据库需要额外的空间存放归档日志，而且写出归档日志会为数据库带来性能负担，但是归档模式可以为数据库带来强大的可恢复性，所以生产数据库通常都应该运行在归档模式下，当然归档模式应该和相应的备份策略相结合,比如由于缺乏必要的监控和备份策略，在归档模式下由于归档空间耗尽而导致数据库故障。

最危险的数据库是什么样子的？答案很简单：**非归档、无备份**。更改数据库的归档模式需要重新启动数据库，在mount模式下修改，以下是步骤说明。

1. 修改必要的初始化参数。
2. 以 immediate 方式关闭数据库。
3. 启动实例到 mount 状态。

以下简单介绍如何启用和关闭数据库的归档模式。

（1）修改初始化参数。和归档相关的几个主要参数如下

- log_archive_format：用于定义归档文件格式，可以采用缺省值。
- log_archive_dest：用于定义归档文件路径，与 log_archive_dest_n 参数不兼容。
- log_archive_dest_n：Oracle允许定义多个归档路径，一般可以使用log_archive_dest_1参数即可。

（2）关闭数据库。

以 shutdown normal 或 shutdown immediate 方式关闭数据库：

（3）启动数据库到 mount 状态：

（4）启用或停止归档模式。

如果要启用归档模式，此处使用 alter database archivelog 命令：

```sql
SQL> alter database archivelog;  
SQL> alter database open;  
SQL> archive log list;  
Database log mode              Archive Mode  
Automatic archival             Enabled  
Archive destination            /opt/oracle/archive  
Oldest online log sequence       148  
Next log sequence to archive     151  
Current log sequence             151  
```

如果需要停止归档模式，此处使用 alter database noarchivelog 命令：

```sql
SQL> alter database noarchivelog;   
SQL> alter database open;   
```

## 4. 逻辑备份与恢复

导入/导出(IMP/EXP)是Oracle最古老的两个命令行工具，通过导出(EXP)工具可以将Oracle数据库中的数据提取出来，在恢复时可以将数据导入(IMP)进行恢复。

但是需要注意的是，使用EXP备份的数据进行全库恢复时，需要重新创建数据库，导入备份的数据，恢复的过程可能会极为漫长。

从Oracle 10g开始，Oracle引入了一个新的导入和导出工具数据泵(Oracle Data Pump)，数据泵与传统的导入/导出(IMP/EXP)工具完全不同，它包含两个实用工具EXPDP和IMPDP，分别对应导出与导入工作。

在Oracle10g之前，导入和导出(IMP/EXP)都作为客户端程序运行，导出的数据由数据库实例读出，通过网络连接传输到导出客户程序，然后写到磁盘上。所有数据在整个导出进程下通过单线程操作，在很多情况下，这种单一导出进程的操作方式成为了一个瓶颈，而且如果在导出过程中发生网络终端或客户端程序异常，都会导致导出操作失败；在Oracle 10g中，数据泵(Data Pump)的所有工作都由数据库实例来完成，数据库可以并行来处理这些工作，不仅可以通过建立多个数据泵工作进程来读/写正在被导出/导入的数据，也可以建立并行I/O服务器进程以更快地读取(SELECT)或插入(INSERT)数据，从而，单进程瓶颈被彻底解决。

通过数据泵，以前通过EXP/IMP主要基于Client/Server的逻辑备份方式转换为服务器端的快速备份，数据泵(EXPDP/IMPDP)主要工作在服务器端，可以通过并行方式快速装入或卸载数据，而且可以在运行过程中调整并行的程度，以加快备份或减少资源耗用。

## 5. 物理备份与恢复

物理备份是指针对Oracle的文件进行的备份，这与逻辑备份针对数据的备份不同。在物理备份中，数据库使用的重要文件都需要进行针对性的备份，这些文件包括**数据文件(DATAFILE)、控制文件(CONTROLFILE)、联机日志文件(REDOLOG)、归档日志文件(ARCHIVELOG)和参数文件及口令文件(可选)**等。

需要注意的是，临时文件因为不存储永久数据，所以可以不必备份，在恢复后可以重新创建临时表空间的临时文件。根据备份方式的不同，物理备份又可以分为冷备份和热备份。

### 5.1 冷备份

冷备份是指关闭数据库的备份，又称脱机备份或一致性备份，在冷备份开始前数据库必须彻底关闭。关闭操作必须用带有normal、transaction、immediate选项的shutdown来执行。

冷备份通常适用于业务具有阶段性的企业，比如白天运行、夜间可以停机维护的企业，冷备份操作简单，但是需要关闭数据库，对于需要24×7提供服务的企业是不适用的。

以下几个查询在备份之前应当执行，以确认数据库文件及存储路径：

```sql
SQL> select name from V$datafile;		--数据文件
NAME
--------------------------------------------------------------------------------
/u01/app/oracle/oradata/orcl/system01.dbf
/u01/app/oracle/oradata/orcl/sysaux01.dbf
/u01/app/oracle/oradata/orcl/undotbs01.dbf
/u01/app/oracle/oradata/orcl/users01.dbf
/u01/app/oracle/oradata/orcl/example01.dbf
/u01/app/oracle/oradata/orcl/DEV_odi_user.dbf
/u01/app/oracle/oradata/orcl/apex_01.dbf
/u01/app/oracle/oradata/orcl/APEX_6121090681146232.dbf
8 rows selected

SQL> select member from v$logfile;		--日记文件
MEMBER
--------------------------------------------------------------------------------
/u01/app/oracle/oradata/orcl/redo03.log
/u01/app/oracle/oradata/orcl/redo02.log
/u01/app/oracle/oradata/orcl/redo01.log

SQL> select name from v$controlfile;		--控制文件
NAME
--------------------------------------------------------------------------------
/u01/app/oracle/oradata/orcl/control01.ctl		
/u01/app/oracle/flash_recovery_area/orcl/control02.ctl
```

冷备份的通常步骤是：
（1）正常关闭数据库；
（2）备份所有重要的文件到备份目录；
（3）完成备份后启动数据库。

为了恢复方便，冷备份应该包含所有的数据文件、控制文件和日志文件，这样当需要采用冷备份进行恢复时，只需要将所有文件恢复到原有位置，就可以启动数据库了。

### 5.2 热备份

由于冷备份需要关闭数据库，所以已经很少有企业能够采用这种方式进行备份了，当数据库运行在归档模式下时，Oracle允许用户对数据库进行联机热备份。

热备份又可以简单地分为两种：用户管理的热备份（user-managed backup and recovery）和Oracle 管理的热备份（Recovery Manager-RMAN）。

用户管理的热备份是指用户通过将表空间置于热备份模式下，然后通过操作系统工具对文件进行复制备份，备份完成后再结束表空间的备份模式。

Oracle管理的热备份通常指通过RMAN对数据库进行联机热备份，RMAN执行的热备份不需要将表空间置于热备模式，从而可以减少对于数据库的影响获得性能提升。另外RMAN的备份信息可以通过控制文件或者额外的目录数据库进行管理，功能强大但是相对复杂。

下面分别来介绍一下用户管理的备份和 RMAN。

用户管理的热备份通常包含以下几个步骤：

（1）在备份之前需要显示的发出 Begin Backup 的命令；
（2）在操作系统拷贝备份文件（包括数据文件、控制文件等）；
（3）发出 end backup 命令通知数据库完成备份；
（4）备份归档日志文件。

常见的备份过程如下，这里以一个表空间的备份为例：

	alter tablespace system begin backup; 
	host copy E:\ORACLE\ORADATA\EYGLE\SYSTEM01.DBF e:\oracle\orabak\SYSTEM01.DBF 
	alter tablespace system end backup; 
	
当备份被激活时，可以通过 v$backup 视图来检查表空间的备份情况：

	SQL> select file#,status,change#,time from v$backup; 
		 FILE# STATUS                CHANGE# TIME
	---------- ------------------ ---------- -----------
			 1 ACTIVE             6051905222 2018/5/8 7:
			 2 NOT ACTIVE                  0 
			 3 NOT ACTIVE                  0 
			 4 NOT ACTIVE                  0 
			 5 NOT ACTIVE                  0 

要注意的是，当表空间置于热备模式下，表空间数据文件头的检查点会被冻结，当热备份完成，发出endbackup命令后，表空间数据文件检查点被重新同步，恢复更新。

这里需要提醒的是，**如果遗忘了end backup命令将会导致数据库问题**，所以使用这种方式备份时需要确认备份正确完成。

### 5.3 额外 Redo 的生成

在使用BeginBackup开始备份时，数据库会产生了比平常更多的日志，也就会生成更多的归档。这是因为在热备份期间，Oracle为了解决SPLITBLOCK的问题，需要在日志文件中记录修改的行所在的数据块的前镜像(image)，而不仅仅是修改信息。

为了理解这段话，还需要简单介绍一下SPLIT BLOCK的概念。我们知道，Oracle的数据块是由多个操作系统块组成。通常UNIX文件系统使用512bytes的数据块，而Oracle使用8kB的db_block_size。当热备份数据文件的时候，使用文件系统的命令工具(通常是cp工具)拷贝文件，并且使用文件系统的blocksize读取数据文件。

在这种情况下，可能出现如下状况：当拷贝数据文件的同时，数据库正好向数据文件写数据。这就使得拷贝的文件中包含这样的database block，它的一部分OS block来自于数据库向数据文件(这个dbblock)写操作之前，另一部分来自于写操作之后。对于数据库来说，这个database block本身并不一致，而是一个分裂块(SPLITBLOCK)。这样的分裂块在恢复时并不可用(会提示corrupted block)。

所以，在热备状态下，对于变更的数据，Oracle需要在日志中记录整个变化的数据块的前镜像。这样如果在恢复的过程中，数据文件中出现分裂块，Oracle就可以通过日志文件中的数据块的前镜像覆盖备份，以完成恢复。

分裂块产生的根本原因在于备份过程中引入了操作系统工具(如cp工具等)，操作系统工具无法保证Oracle数据块的一致性。如果使用RMAN备份，由于Rman可以通过反复读取获得一致的Blok，从而可以避免SPLITBlock的生成，所以不会产生额外的REDO。所以建议在备份时(特别是繁忙的数据库)，应该尽量采用RMAN备份。

### 5.4 Oracle 10g 的增强

在 Oracle 10g 中， Oracle 新增命令用以简化用户管理的备份，现在可以通过 alter database begin/end backup 来进行数据库备份模式的切换，在 Oracle 10g 之前，需要对每个表空间逐一进行热备设置。

	SQL>alter database begin backup;
	Database altered.
	
当执行了 alter database begin backup 之后，所有表空间一次被置于热备状态，可以通过并行方式对数据库进行备份。在执行 alter database end backup，所有表空间将一次性停止热备：

	SQL> alter database end backup; 
	Database altered. 