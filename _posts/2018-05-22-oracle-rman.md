---
layout: post
title: Oracle RMAN基础
categories: [Oracle]
tags: RMAN
---

> 用户管理的备份与恢复方法比较复杂，需要对Oracle比较了解。从Oracle 8开始，Oracle提供了一个比较容易操作的工具RMAN，Oracle推荐使用这个工具进行备份和恢复。

## 1. RMAN介绍

Recovery Manager（RMAN)是一个用于备份(Backup)、还原(Restore)和恢复(Recover)的Oracle工具，它能够备份整个数据库或数据库部件，如表空间、数据文件、控制文件、归档文件以及Spfile参数文件。使用RMAN也能进行增量数据备份，增量备份能节约时间和空间，因为增量RMAN备份只备份自上次备份以来有变化的数据块。RMAN还提供许多高级功能，如数据库的克隆、建立备用数据库、备份与移动裸设备等。


和用户管理的备份方式相比，使用 RMAN 具有以下一系列的优点:

- 备份执行期间不需要人工介入，从而减少了误操作的可能。

- 可以有效的将备份和恢复结合起来。

- 支持除逻辑备份以外的所有备份类型，包括完全备份、增量备份、表空间备份、数据文件备份、控制文件备份以及归档日志文件备份等。

- 可以通过 RMAN 识别 corrupted block，并可以通过 RMAN 进行块级恢复。

- 方便的实现定期（定时）备份。

- 自动生成备份日志。

- RMAN 的备份脚本和 OS 无关，方便移植。

- 强大的报表功能可以方便地获悉备份的可用性。

- RMAN 备份可以跳过未使用过的数据块，从而缩减备份集大小。当使用系统工具拷贝Oracle文件进行备份时，是无法区分Oracle数据块是否使用的，RMAN则可以根据高水位标记（High Water Mark-HWM）来识别从未使用过的数据块，在备份时这些数据块可以被跳过。

- 从 Oracle 10g 开始， Oracle 可以对备份集进行压缩，从而缩减备份空间的占用。备份压缩会消耗额外的CPU资源，但是可以节省存储，具体应该根据系统情况进行考虑。

- 从 Oracle10g 开始，通过 RMAN可以实现跨平台的表空间迁移。

可以看到，以上的一些优点中，显示了RMAN强大的功能。RMAN备份与恢复是基于块级别的，通过比较数据块避免备份没有使用过的块。

## 2. RMAN组成

RMAN的组成如图:

![](/images/posts/20180628092059.jpg)

组成RMAN的各组件如下：

### 1．RMAN工具 

RMAN的命令集合起源于Oracle 8，一般位于$ORACLE_HOME/bin 目录下。用户可以通过运行rman命令来启动RMAN工具。

### 2. 服务器进程

RMAN的服务器进程是一个后台进程，用于与RMAN工具与数据库之间的通信，也用于RMAN工具与磁盘/磁带等I/O设备之间的通信，服务器进程负责备份与恢复的所有工作。

### 3. 通道

通道是服务器进程与I/O 设备之间读写的途径。一个通道将对应一个服务进程。在分配通道时，需要考虑I/O设备的类型、I/O并发处理的能力、I/O设备能创建的文件的大小、数据库文件最大的读速率、最大的打开文件数目等因素。

### 4. 目标数据库

目标数据库就是使用RMAN 进行备份与恢复的数据库。RMAN可以备份除了日志文件、Pfile、口令文件之外的数据文件、控制文件、归档日志文件、Spfile文件。

### 5. 恢复目录

用来保存备份与恢复信息的一个数据库，不建议创建在目标数据库上。利用恢复目录可以同时管理多个目标数据库，存储更多的备份信息，存储备份脚本。如果不采用恢复目录，可以采用控制文件来代替恢复目录。

### 6．介质管理层

Media Management Layer（MML）是一个第三方工具，用于管理对磁带的读写与文件的跟踪管理。 

### 7．备份集与备份片 

使用备份命令备份数据库后，RMAN将备份存到一个或多个物理文件中，这些物理文件就是一个备份集，备份集是一个逻辑结构。备份集内的物理文件就是备份片。备份片是最基本的物理结构，可以存在磁盘或者磁带上，可以包含目标数据库的数据文件、控制文件、归档日志与Spfile文件。

### 8．RMAN 资料库 

RMAN资料库（RMAN Repository）存储了目标数据库的元数据（Metadata ）和使用RMAN备份的备份集信息，例如备份集的位置，备份集内包括的备份片，备份集的状态等。RMAN进行备份和恢复操作都要访问RMAN资料库。

## 3.连接RMAN  


运行RMAN需要SYSDBA 系统权限。RMAN工具版本与目标数据库必须是同一个版本。如果使用了恢复目录，还需要注意创建RMAN恢复目录的脚本版本必须等于或大于恢复目录所在数据库的版本。创建RMAN恢复目录的脚本版本必须等于或大于目标数据库的版本。

### 3.1 启动RMAN

使用RMAN 必须连接到目标数据库。如果使用恢复目录，还要使用恢复目录数据库；如果使用辅助数据库，还要连接到辅助数据库。连接到数据库的方法有两种：一是在启动RMAN命令时指定要连接的数据库；二是在启动RMAN后在RMAN提示符下输入CONNECT命令连接数据库。

使用CONNECT 命令连接目标数据库时，如果使用恢复目录，就在CONNECT命令后面指定CATALOG选项，使用NOCATALOG选项指定不使用恢复目录，默认不使用恢复目录。CONNECT命令连接到目标数据库的格式是：

	CONNECT TARGET 用户名/口令@连接描述符

如果要连接到恢复目录数据库，指定CATALOG 选项，格式如下： 

	CONNECT CATALOG 用户名/口令@连接描述符
	
如果要连接到辅助数据库，指定AUXILIARY 选项，格式如下： 
 
	CONNECT AUXILIARY 用户名/口令@连接描述符 

### 3.2 运行RMAN命令 

RMAN可以运行单个命令，也可以运行一个命令块、脚本文件命令。

#### 1．执行单个命令

大多数RMAN 命令都可以单独执行。这些命令包括关闭目标数据库命令SHUTDOWN、启动目标数据库命令STARTUP、备份表空间BACKUP TABLESPACE命令等。下面的命令备份USERS表空间：

```
RMAN> BACKUP FORMAT '/u01/rman/%d_%s.bak'  TABLESPACE USERS; 

Starting backup at 28-JUN-18
using channel ORA_DISK_1
channel ORA_DISK_1: starting full datafile backup set
channel ORA_DISK_1: specifying datafile(s) in backup set
input datafile file number=00004 name=/u01/app/oracle/oradata/orcl/users01.dbf
channel ORA_DISK_1: starting piece 1 at 27-JUN-18
channel ORA_DISK_1: finished piece 1 at 27-JUN-18
piece handle=/u01/rman/ORCL_5.bak tag=TAG20180627T134122 comment=NONE
channel ORA_DISK_1: backup set complete, elapsed time: 00:00:01
Finished backup at 28-JUN-18

Starting Control File and SPFILE Autobackup at 28-JUN-18
piece handle=/u01/app/oracle/flash_recovery_area/ORCL/autobackup/2018_06_27/o1_mf_s_979911683_fm68w3xo_.bkp comment=NONE
Finished Control File and SPFILE Autobackup at 28-JUN-18
```

#### 2. 运行一个命令块 

在RMAN下可以运行命令块。命令块是一组RMAN命令。当执行一个任务时，可以将这个任务的所有命令放在一个命令块中。但CONNECT、CREATE/DELETE/UPDATECATALOG、CREATE/DELETE/REPLACESCRIPT、LIST等RMAN命令不能包含在RUN命令块内。以下是执行命令块的例子：

```
RMAN>  run {  
2> allocate channel d1 type disk;  
3> BACKUP FORMAT 'D: \%d_%s.bak' TABLESPACE USERS;  
4> release channel d1; 
5> } 
```

#### 3. 运行SQL命令 

在RMAN中可以运行 SQL 命令，运行SQL 命令的格式是： 

	RMAN>SQL 'SQL 语句';
	例如：
	RMAN>SQL 'ALTER SYSTEM CHECKPOINT';
	
#### 4．运行脚本

可以使用RMAN 运行脚本。存储了脚本后，在RUN块内运行。例如，以下命令执行脚本文件S1：

	RMAN> RUN { EXECUTE SCRIPT S1;} 

#### 5. 运行操作系统命令

在RMAN内可以运行操作系统命令，运行操作系统命令的格式为： 

```
RMAN> host 'pwd';

/u01/rman
host command complete
``` 

## 4. RMAN 的配置

从Oracle 9i 开始，Oracle 为RMAN会话进行了默认的环境配置。用户也可以通过CONFIGURE命令配置RMAN的环境。

使用show all 命令可以显示已配置的所有 RMAN信息，
 
```
RMAN> show all;

using target database control file instead of recovery catalog
RMAN configuration parameters for database with db_unique_name ORCL are:
CONFIGURE RETENTION POLICY TO REDUNDANCY 1; # default
CONFIGURE BACKUP OPTIMIZATION OFF; # default
CONFIGURE DEFAULT DEVICE TYPE TO DISK; # default
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '%F'; # default
CONFIGURE DEVICE TYPE DISK PARALLELISM 1 BACKUP TYPE TO BACKUPSET; # default
CONFIGURE DATAFILE BACKUP COPIES FOR DEVICE TYPE DISK TO 1; # default
CONFIGURE ARCHIVELOG BACKUP COPIES FOR DEVICE TYPE DISK TO 1; # default
CONFIGURE MAXSETSIZE TO UNLIMITED; # default
CONFIGURE ENCRYPTION FOR DATABASE OFF; # default
CONFIGURE ENCRYPTION ALGORITHM 'AES128'; # default
CONFIGURE COMPRESSION ALGORITHM 'BASIC' AS OF RELEASE 'DEFAULT' OPTIMIZE FOR LOAD TRUE ; # default
CONFIGURE ARCHIVELOG DELETION POLICY TO NONE; # default
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '/u01/app/oracle/product/11.2.0/db_1/dbs/snapcf_orcl.f'; # default
```

### 4.1 设置备份保持策略

使用RMAN 对数据库执行多次备份后，可能存在多个备份文件。保持策略就是设置将备份文件置为陈旧Obsolete的时机。有两种备份保持策略：一个是时间策略，决定多长时间后将备份置陈旧标记；一个是冗余策略，规定最多能保留几个冗余备份。

表示从当前日期开始算起，将5 天之前的备份标记为陈旧 Obsolete：
	
	RMAN> CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 5 DAYS;

表示只能保留5 个冗余的备份，超过 5 个后，超过的备份置陈旧标记：
	
	RMAN> CONFIGURE RETENTION POLICY TO REDUNDANCY 5;  
 
表示使用NONE 子句使备份保持策略失效：

	RMAN> CONFIGURE RETENTION POLICY TO NONE;  

### 4.2 设置控制文件自动备份  

从Oracle 9i 开始，可以配置控制文件的自动备份，但是这个设置不能使用在备用数据库上。通过以下命令设置控制文件自动备份：

	RMAN> CONFIGURE CONTROLFILE AUTOBACKUP ON;

对于没有恢复目录的备份策略来说，这个特性是特别有效的，控制文件的自动备份发生在任何backup或者copy命令之后，或者任何数据库的结构改变之后。

### 4.3 设置并行备份 

RMAN支持并行备份与恢复，也可以在配置中指定默认的并行程度，例如： 
 
	RMAN> CONFIGURE DEVICE TYPE DISK PARALLELISM 4; 
 
在以后的备份与恢复中，将采用并行度为4，即同时开启4个通道进行备份与恢复。当然也可以在run的运行块中指定通道来决定备份与恢复的并行数目。并行的数目决定了开启通道的个数。如果指定了通道配置，将采用指定的通道，如果没有指定通道，将采用默认通道配置。

### 4.4 配置默认I/O 设备类型

I/O 设备类型可以是磁盘或者磁带，默认是磁盘，通过以下命令配置默认设备类型： 

	RMAN> CONFIGURE DEFAULT DEVICE TYPE TO DISK;  
	
设置默认I/O 设备为磁盘。 
 
### 4.5 配置多重备份

如果单个备份不保险，可以同时生成多个备份集。例如： 
 
	RMAN> CONFIGURE DATAFILE BACKUP COPIES FOR DEVICE TYPE DISK TO 2;
	
备份数据文件时向磁盘备份两个完全一样的备份集

	RMAN> CONFIGURE ARCHIVELOG BACKUP COPIES FOR DEVICE TYPE DISK TO 2;
 
### 4.6 备份优化 

备份优化用于在一些特殊条件下跳过某个特定备份。使用语句BACKUP DATABASE、BACKUP ARCHIVELOG ALL/LIKE或者BACKUP BACKUPSET ALL进行备份优化，默认情况下，RMAN禁止备份优化，使用以下语句开启备份优化：

	RMAN>CONFIGURE BACKUP OPTIMIZATION ON;
	
## 5. 备份文件的格式 

备份文件可以自定义各种各样的格式，格式的符号如下。 

- %c：备份片的复制数。 
- %d：数据库名称。 
- %D：位于该月中的第几天（DD）。 
- %M：位于该年中的第几月（MM）。 
- %F：一个基于 DBID唯一的名称，这个格式的形式为 c -IIIIIIIIII- YYYYMMDD-QQ，其中IIIIIIIIII 为该数据库的DBID，YYYYMMDD为日期，QQ是一个1～256的序列。
- %n：数据库名称，向右填补到最多 8 个字符。 
- %u：一个8 个字符的名称代表备份集与创建时间。 
- %p：该备份集中的备份片号，从 1 开始到创建的文件数。 
- %U：一个唯一的文件名，代表- %u_- %p_- %c 。 
- %s：备份集的号。 
- %t：备份集时间戳。 
- %T：年月日格式（YYYYMMDD）。 