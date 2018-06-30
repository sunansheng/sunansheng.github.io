---
layout: post
title: Oracle SCN 与 Checkpoint
categories: [Oracle]
tags: SCN
---

## 1. SCN 

Oracle数据库在内部通过SCN(Systems Change Numbers)和检查点来保证数据库的一致性、可恢复性等重要属性。

SCN就是通常所说的系统改变号，是数据库中非常重要的一个数据结构，用以标识数据库在某个确切时刻提交的版本。在事务提交时，它被赋予一个唯一的标示事务的SCN。SCN同时被作为Oracle数据库的内部时钟机制，可以被看作逻辑时钟，每个数据库都有一个全局的SCN生成器。

作为数据库内部的逻辑时钟，数据库事务依SCN而排序，Oracle也依据SCN来实现一致性读(Read Consistency)等重要数据库功能，另外对于分布式事务(Distributed Transactions)，SCN也极为重要。SCN在数据库中是唯一的，并随时间而增加，但是可能并不连贯。除非重建数据库，SCN的值永远不会被重置为0。

SCN在数据库中是无处不在的，常见的事务表、控制文件、数据文件头、日志文件、数据块头等都记录有SCN值。

## 2. SCN 的获取方式

从Oracle 10g开始,在v$database视图中增加了current_scn字段，通过查询该字段可以获得数据库的当前SCN值：

	SQL> select current_scn,checkpoint_change# from v$database;

	   CURRENT_SCN CHECKPOINT_CHA
	-------------- --------------
	 6051905079258  6051905079087
	
## 3. SCN 的进一步说明

系统当前SCN并不是在任何的数据库操作发生时都会改变，**SCN通常在事务提交或回滚时改变**，在控制文件、数据文件头、数据块、日志文件头中都有SCN，但其作用各不相同。

### 3.1 控制文件

由于控制文件是个二进制文件，无法直接打开查阅，但是通过以下命令可以将控制文件内容转储出来进行查看：

	alter session set events 'immediate trace name controlf level 8';  
	
查询转存文件：

```
SQL> select value from v$diag_info where name='Default Trace File';

VALUE
--------------------------------------------------------------------------------
/u01/app/oracle/diag/rdbms/orcl/orcl/trace/orcl_ora_24332.trc
```
	
包含数据库的名称、数据文件及日志文件的数量、数据库的检查点及SCN信息等：

```
Db ID=1422785319=0x54cdfb27, Db Name='ORCL' 			#"数据库名称"
…… …… 
name #7: /u01/app/oracle/oradata/orcl/system01.dbf
creation size=0 block size=8192 status=0xe head=7 tail=7 dup=1
tablespace 0, index=1 krfil=1 prev_file=0
unrecoverable scn: 0x0000.00000000 01/01/1988 00:00:00
Checkpoint cnt:896 scn: 0x0581.11a7072f 05/07/2016 02:47:32 	#"数据文件 Checkpoint scn"
Stop scn: 0xffff.ffffffff 04/28/2016 10:19:34 			#"数据文件 Stop scn"
Creation Checkpointed at scn:  0x0000.00000007 08/15/2009 00:16:48
```

### 3.2 数据文件头

数据文件头中包含了该数据文件的 Checkpoint SCN ，表示该数据文件最近一次执行检查点操作时的 SCN 。


	SQL> select name, checkpoint_change# from v$datafile where name like '%user%';

	NAME                                                                             CHECKPOINT_CHA
	-------------------------------------------------------------------------------- --------------
	/u01/app/oracle/oradata/orcl/users01.dbf                                          6051905079087
	/u01/app/oracle/oradata/orcl/DEV_odi_user.dbf                                     6051905079087


### 3.3 日志文件头

日志文件头中包含了 Low SCN和Next SCN。 

这两个SCN标示该日志文件包含有介于Low SCN到Next SCN的重做信息，对于Current的日志文件(当前正在被使用的Redo Logfile)，其最终SCN不可知，所以Next SCN被置为无穷大，也就是ffffffff。

来看一下日志文件的情况： 

	SQL> select l.STATUS,l.FIRST_CHANGE#,l.NEXT_CHANGE# from v$log l;

	STATUS           FIRST_CHANGE# NEXT_CHANGE#
	---------------- ------------- ------------
	CURRENT          6051905004905 281474976710655
	INACTIVE         6051904998000 6051905001479
	INACTIVE         6051905001479 6051905004905
	
Oracle在进行恢复时就需要根据低SCN和高SCN来确定需要的恢复信息位于哪一个日志或归档文件中。

## 4. 检查点

检查点是一个数据库事件，它存在的根本意义在于**减少崩溃恢复(Crash Recovery)时间**。检查点事件由CKPT后台进程触发，当检查点发生时，CKPT进程会负责通知DBWR进程将脏数据(Dirty Buffer)写出到数据文件上。CKPT进程的另外一个职责是负责更新数据文件头及控制文件上的检查点信息。

### 4.1 检查点（Checkpoint）的工作原理 

在Oracle数据库中，当进行数据修改时，需要首先将数据读入内存中(Buffer Cache)，修改数据的同时，Oracle会记录重做(Redo)信息用于恢复。因为有了重做信息的存在，Oracle不需要在事务提交时(Commit)立即将变化的数据写回磁盘**(立即写的效率会很低)，**重做的存在也正是为了在数据库崩溃之后，数据可以恢复。

> When a checkpoint occurs. Oracle must update the headers of all datafiles to record the details of the checkpoint. This is done by the CKPT process. The CKPT process does not write blocks to disk; DBWn always performs that work.
 
最常见的情况，数据库可能因为断电而Crash，那么内存中修改过的、尚未写入数据文件的数据将会丢失。在下一次数据库启动之后，Oracle可以通过重做(Redo)日志进行事务重演(也就是进行前滚)，将数据库恢复到崩溃之前的状态，然后数据库可以打开提供使用，之后Oracle可以将未提交的事务进行回滚。
 
在这个启动过程中，通常大家最关心的是数据库要经历多久才能打开。也就是需要读取多少重做日志才能完成前滚。当然我们希望这个时间越短越好，Oracle也正是通过各种手段在不断优化这个过程，缩短恢复时间。

**检查点的存在就是为了缩短这个恢复时间。**当检查点发生时(此时的SCN被称为Checkpoint SCN)Oracle会通知DBWR进程，把修改过的数据，也就是此Checkpoint SCN之前的脏数据(Dirty Data)从Buffer Cache写入磁盘，当写入完成之后，CKPT进程则会相应更新控制文件和数据文件头，记录检查点信息，标识变更。

手动执行Checkpoint：

```sql
SQL> alter system checkpoint;
System altered
```

在检查点完成之后，**此检查点之前修改过的数据都已经写回磁盘，**重做日志文件中的相应重做记录对于崩溃/实例恢复不再有用。 

下图标记了3个日志组，假定在T1时间点，数据库完成并记录了最后一次检查点，在T2时刻数据库Crash。那么在下次数据库启动时，T1时间点之前的Redo不再需要进行恢复，Oracle需要重新应用的就是T1至T2之间数据库生成的重做(Redo)日志。

![](/images/posts/20180623134409.jpg)

检查点的频度对于数据库的恢复时间具有极大的影响，如果检查点的频率高，那么恢复时需要应用的重做日志就相对得少，恢复时间就可以缩短。然而，需要注意的是，数据库内部操作的相关性极强，过于频繁的检查点同样会带来性能问题，尤其是更新频繁的数据库。所以数据库的优化是一个系统工程，不能草率。



## 5. Oracle SCN机制解析

我们先看下oracle事务中的数据变化是如何写入数据文件的：

1. 事务开始；

2. 在buffer cache中找到需要的数据块，如果没有找到，则从数据文件中载入buffer cache中；

3. 事务修改buffer cache的数据块，该数据被标识为“脏数据”，并被写入log buffer中；

4. 事务提交，LGWR进程将log buffer中的“脏数据”写入redo log file中；

5. 当发生checkpoint，CKPT进程更新所有数据文件的文件头中的信息，DBWn进程则负责将Buffer Cache中的脏数据写入到数据文件中。

经过上述5个步骤，事务中的数据变化最终被写入到数据文件中。但是，一旦在上述中间环节时，数据库意外宕机了，在重新启动时如何知道哪些数据已经写入数据文件、哪些没有写呢（同样，在DG、streams中也存在类似疑问：redo log中哪些是上一次同步已经复制过的数据、哪些没有）？SCN机制就能比较完善的解决上述问题。

SCN是一个数字，确切的说是一个只会增加、不会减少的数字。正是它这种只会增加的特性确保了Oracle知道哪些应该被恢复、哪些应该被复制。