---
layout: post
title: Oracle RMAN备份与恢复
categories: [Oracle]
tags: RMAN
---

## 1. 备份整个数据库

使用BACKUP DATA BASE 命令备份整个数据库，也就是进行完全数据库备份。完全数据库备份又有一致性备份和非一致性备份两种。

### 1.1 一致性备份

执行一致性完全数据库备份必须在数据库关闭时执行。完全数据库备份主要备份所有的数据文件和控制文件。完全数据库一致性备份既适用于ARCHIVELOG模式，也适用于NOARCHIVELOG模式。完全数据库备份有以下步骤。

（1）关闭数据库。使用以下命令： 

	RMAN> SHUTDOWN IMMEDIATE 
	
（2）启动数据库到装载状态。使用以下命令： 

	RMAN> STARTUP MOUNT 

（3）使用BACKUP DATABASE 备份数据库，格式如下： 

```
RMAN> BACKUP DATABASE FORMAT='/u01/rman/%d_%s.db';

Starting backup at 28-JUN-18
allocated channel: ORA_DISK_1
channel ORA_DISK_1: SID=192 device type=DISK
channel ORA_DISK_1: starting full datafile backup set
channel ORA_DISK_1: specifying datafile(s) in backup set
input datafile file number=00002 name=/u01/app/oracle/oradata/orcl/sysaux01.dbf
input datafile file number=00001 name=/u01/app/oracle/oradata/orcl/system01.dbf
input datafile file number=00007 name=/u01/app/oracle/oradata/orcl/apex_01.dbf
input datafile file number=00003 name=/u01/app/oracle/oradata/orcl/undotbs01.dbf
input datafile file number=00006 name=/u01/app/oracle/oradata/orcl/DEV_odi_user.dbf
input datafile file number=00005 name=/u01/app/oracle/oradata/orcl/example01.dbf
input datafile file number=00008 name=/u01/app/oracle/oradata/orcl/APEX_6121090681146232.dbf
input datafile file number=00004 name=/u01/app/oracle/oradata/orcl/users01.dbf
channel ORA_DISK_1: starting piece 1 at 27-JUN-18
channel ORA_DISK_1: finished piece 1 at 27-JUN-18
piece handle=/u01/rman/ORCL_14.db tag=TAG20180627T173852 comment=NONE
channel ORA_DISK_1: backup set complete, elapsed time: 00:00:25
Finished backup at 28-JUN-18
```

（4）打开数据库到打开（OPEN）状态，可以使用以下命令： 

	RMAN> alter database open;
	
### 1.2 非一致性备份

非一致性备份能在数据库处于OPEN 状态下完成。因为非一致性备份数据库文件和控制文件的SCN号可能不一致，为完全恢复数据库，非一致性备份只能用于ARCHIVELOG模式。非一致性备份使用的命令与一致性备份一致：

	RMAN> BACKUP DATABASE FORMAT='/u01/rman/%d_%s.db';
	
## 2.备份部分数据库

备份部分数据库指使用BACKUP TABLESPACE命令备份一个或多个表空间、数据文件、控制文件等。

### 2.1 备份表空间

使用BACKUP TABLESPACE 命令备份一个或多个表空间，表空间备份只适用于ARCHIVELOG 模式，并且数据库必须处于OPEN 状态。下面命令备份USERS表空间： 

```
RMAN> BACKUP TABLESPACE USERS FORMAT '/u01/rman/%N_%f_%s.tab'; 

Starting backup at 28-JUN-18
using channel ORA_DISK_1
channel ORA_DISK_1: starting full datafile backup set
channel ORA_DISK_1: specifying datafile(s) in backup set
input datafile file number=00004 name=/u01/app/oracle/oradata/orcl/users01.dbf
channel ORA_DISK_1: starting piece 1 at 27-JUN-18
channel ORA_DISK_1: finished piece 1 at 27-JUN-18
piece handle=/u01/rman/USERS_4_18.tab tag=TAG20180627T174808 comment=NONE
channel ORA_DISK_1: backup set complete, elapsed time: 00:00:01
Finished backup at 28-JUN-18
```

如果要备份多个表空间，就将多个表空间名称列出来，名称之间用逗号隔开，例如以下命令备份USERS和SYSTEM表空间：

	RMAN> BACKUP TABLESPACE USERS,SYSTEM FORMAT '/u01/rman/%N_%f_%s.tab'; 
	
### 2.2 备份数据文件

使用BACKUP DATAFILE 命令备份数据文件，以下是备份数据文件的例子：

```
RMAN> BACKUP DATAFILE 5 FORMAT='/u01/rman/%f_%s.dat';

Starting backup at 28-JUN-18
using channel ORA_DISK_1
channel ORA_DISK_1: starting full datafile backup set
channel ORA_DISK_1: specifying datafile(s) in backup set
input datafile file number=00005 name=/u01/app/oracle/oradata/orcl/example01.dbf
channel ORA_DISK_1: starting piece 1 at 27-JUN-18
channel ORA_DISK_1: finished piece 1 at 27-JUN-18
piece handle=/u01/rman/5_20. dat  tag=TAG20180627T175537 comment=NONE
channel ORA_DISK_1: backup set complete, elapsed time: 00:00:01
Finished backup at 28-JUN-18
```

### 2.3 备份控制文件

使用BACKUP CURRENT CONTROLFILE 命令备份当前控制文件，以下命令备份当前控制文件：

```
RMAN> BACKUP CURRENT CONTROLFILE FORMAT='/u01/rman/ctl%d_%s.ctl';

Starting backup at 28-JUN-18
using channel ORA_DISK_1
channel ORA_DISK_1: starting full datafile backup set
channel ORA_DISK_1: specifying datafile(s) in backup set
including current control file in backup set
channel ORA_DISK_1: starting piece 1 at 27-JUN-18
channel ORA_DISK_1: finished piece 1 at 27-JUN-18
piece handle=/u01/rman/ctlORCL_22.ctl tag=TAG20180627T175747 comment=NONE
channel ORA_DISK_1: backup set complete, elapsed time: 00:00:01
Finished backup at 28-JUN-18
```

### 2.4 备份Spfile文件

使用BACKUP Spfile 命令备份服务器参数文件。如:

```
RMAN> BACKUP Spfile FORMAT='/u01/rman/spfile_%d_%s.spf' ;

Starting backup at 28-JUN-18
using channel ORA_DISK_1
channel ORA_DISK_1: starting full datafile backup set
channel ORA_DISK_1: specifying datafile(s) in backup set
including current SPFILE in backup set
channel ORA_DISK_1: starting piece 1 at 27-JUN-18
channel ORA_DISK_1: finished piece 1 at 27-JUN-18
piece handle=/u01/rman/spfile_ORCL_24.spf tag=TAG20180627T180039 comment=NONE
channel ORA_DISK_1: backup set complete, elapsed time: 00:00:02
Finished backup at 28-JUN-18
```

### 2.5 备份归档日志文件

```
RMAN> BACKUP ARCHIVELOG FROM TIME='sysdate-1' UNTIL TIME='sysdate' FORMAT='/u01/rman/archivelog_%d_%s.arc'; 

Starting backup at 28-JUN-18
using channel ORA_DISK_1
channel ORA_DISK_1: starting archived log backup set
channel ORA_DISK_1: specifying archived log(s) in backup set
input archived log thread=1 sequence=801 RECID=29 STAMP=979855202
input archived log thread=1 sequence=802 RECID=30 STAMP=979863081
input archived log thread=1 sequence=803 RECID=31 STAMP=979905656
channel ORA_DISK_1: starting piece 1 at 27-JUN-18
channel ORA_DISK_1: finished piece 1 at 27-JUN-18
piece handle=/u01/rman/archivelog_ORCL_26.arc tag=TAG20180627T180425 comment=NONE
channel ORA_DISK_1: backup set complete, elapsed time: 00:00:03
Finished backup at 28-JUN-18
```

## 3. 差异增量备份和累积增量备份

首先要理解差异增量（Differential Backup）备份与累积（Cumulative Backup)增量备份，以及差异增量备份与累积增量备份的备份与恢复原理。使用RMAN建立备份集时，默认是备份数据文件的所有数据块，这种备份也称为完全备份，而增量备份只备份上次备份以来发生变化的数据块。可以使用RMAN增量备份数据文件、表空间或整个数据库。

在Oracle 10g 之前，差异增量备份和累积增量备份都包括0、1、2、3、4共5个备份级别。在Oracle 10g中只使用0、1两个级别，其中级别0相当于完全备份。

### 3.1 差异增量备份

差异增量备份级别1 备份最近一次增量备份（差异增量备份和累积增量备份）变化的数据块。例如，如果要进行级别1差异增量备份，RMAN备份在执行最后一个级别1的增量备份后所变化的数据块；如果之前没有执行过级别1的备份，就备份自执行级别0以后变化的数据块；如果也没执行过级别0的备份，RMAN就复制自文件创建以来变化的所有数据块，否则执行一个级别0的备份。差异增量备份的示意图如图所示。

![](\images\posts/20180628144301.jpg)

周日时执行一个级别为0 的增量备份，周一和周六执行级别为 1 的差异增量备份，即指备份自上一个备份以来变化的数据块。 

### 3.2 累积增量备份

累积增量备份是指备份自最近的级别0备份以来所变化的数据块。累积增量备份能减少恢复时间。累积增量备份的示意图如图所示。

![](\images\posts/20180628144537.jpg)

周日对数据库执行了级别为0的备份。周一到周六执行级别为1的累积增量备份。从图中的箭头可以看出，累积增量备份是备份级别0以来的数据块所做的所有修改。累积增量增加了备份的时间，但是因为恢复的时候，需要从更少的备份集中恢复数据，所以，累积增量备份将比差异增量备份更节省时间。

Oracle 10g 在增量备份上做了很大的改进，可以使增量备份变成真正意义的增量。通过特有的增量日志，使得RMAN没有必要去比较数据库的每一个数据块。但代价是会增加磁盘的I/O。另外，Oracle 10通过备份的合并，使增量备份的结果可以合并在一起，而减少了恢复时间。增量备份都需要一个基础，比如**0级备份**就是所有增量的基础备份，0级备份与全备份的不同就是0级备份可以作为其他增量备份的基础备份而**全备份不可以**。

#### 1.以下是0级备份的例子：

```
RMAN>  BACKUP INCREMENTAL LEVEL 0 DATABASE;

Starting backup at 28-JUN-18
using channel ORA_DISK_1
channel ORA_DISK_1: starting incremental level 0 datafile backup set
channel ORA_DISK_1: specifying datafile(s) in backup set
input datafile file number=00002 name=/u01/app/oracle/oradata/orcl/sysaux01.dbf
input datafile file number=00001 name=/u01/app/oracle/oradata/orcl/system01.dbf
input datafile file number=00004 name=/u01/app/oracle/oradata/orcl/users01.dbf
channel ORA_DISK_1: starting piece 1 at 27-JUN-18
channel ORA_DISK_1: finished piece 1 at 27-JUN-18
piece handle=/u01/app/oracle/flash_recovery_area/ORCL/backupset/2018_06_27/o1_mf_nnnd0_TAG20180627T182439_fm6sh8hg_.bkp tag=TAG20180627T182439 comment=NONE
channel ORA_DISK_1: backup set complete, elapsed time: 00:00:25
```

#### 2.以下是一级差异增量备份的例子：

```
RMAN>  BACKUP INCREMENTAL LEVEL 1 DATABASE;

Starting backup at 28-JUN-18
channel ORA_DISK_1: starting incremental level 1 datafile backup set
channel ORA_DISK_1: specifying datafile(s) in backup set
input datafile file number=00007 name=/u01/app/oracle/oradata/orcl/apex_01.dbf
input datafile file number=00006 name=/u01/app/oracle/oradata/orcl/DEV_odi_user.dbf
input datafile file number=00008 name=/u01/app/oracle/oradata/orcl/APEX_6121090681146232.dbf
channel ORA_DISK_1: starting piece 1 at 27-JUN-18
channel ORA_DISK_1: finished piece 1 at 27-JUN-18
piece handle=/u01/app/oracle/flash_recovery_area/ORCL/backupset/2018_06_27/o1_mf_nnnd1_TAG20180627T182439_fm6sj1z3_.bkp tag=TAG20180627T182439 comment=NONE
channel ORA_DISK_1: backup set complete, elapsed time: 00:00:08
Finished backup at 28-JUN-18
```

#### 3.以下是一级累积增量备份的例子

```
RMAN> BACKUP INCREMENTAL LEVEL 1 CUMULATIVE DATABASE;

Starting backup at 28-JUN-18
using channel ORA_DISK_1
channel ORA_DISK_1: starting incremental level 1 datafile backup set
channel ORA_DISK_1: specifying datafile(s) in backup set
input datafile file number=00002 name=/u01/app/oracle/oradata/orcl/sysaux01.dbf
input datafile file number=00001 name=/u01/app/oracle/oradata/orcl/system01.dbf
input datafile file number=00004 name=/u01/app/oracle/oradata/orcl/users01.dbf
channel ORA_DISK_1: starting piece 1 at 27-JUN-18
channel ORA_DISK_1: finished piece 1 at 27-JUN-18
piece handle=/u01/app/oracle/flash_recovery_area/ORCL/backupset/2018_06_27/o1_mf_nnnd1_TAG20180627T182955_fm6ss4jq_.bkp tag=TAG20180627T182955 comment=NONE
channel ORA_DISK_1: backup set complete, elapsed time: 00:00:15
Finished backup at 28-JUN-18
```




