---
layout: post
title: Oracle 数据库的物理结构
categories: [Oracle]
tags: 物理结构
---

Oracle数据库的物理结构从本质上来说就是一系列的文件。Oracle数据库分为几个部分，第一部分是Oracle RDBMS系统的安装目录，也就是我们常说的ORACLE_HOME。ORACLE_HOME包含了Oracle运行包的几乎所有的文件，当对ORACLE_HOME执行tar命令，并将其复制到一台具有相同操作系统的机器上后，解开包配置一些环境变量就可以使用了，一般来说都不需要做什么特殊的处理。不过由于我们安装操作系统时可能不会完全一致(操作系统的小版本、补丁包、安装的可选包等)，因此针对通过tar命令复制过来的介质，应在使用前做一次重新链接。Oracle在$ORACLE_HOME/bin目录下，提供了用于重新链接的工具，只要进入该目录，执行：

	$relink all
	
就可以完成Oracle介质的重新链接。当然为了便于今后管理，如果要复制一套OracleRDBMS软件介质，不能仅仅复制ORACLE_HOME，还需要创建bdump、udump等目录，为Oracle的前台和后台进程输出日志使用。除此之外，还有一个十分重要的Oracle组件需要进行复制，这就是Inventory。

## 1. Inventory

什么是Inventory呢？Inventory是Oracle安装工具OUI用来管理Oracle安装目录的。Inventory里注册了某个ORACLE_HOME下安装的数据库的组件及其版本。Oracle数据库软件的升级、增删组件，都需要使用Inventory。在一台服务器上，OracleOUI会创建一个全局的Inventory，全局Inventory的目录在oraInst.loc文件中指定。根据操作系统的不同，oraInst.loc所在的目录也不一样。在AIX或者LINUX等系统中，oraInst.loc存放在/etc目录下，在有些操作系统中，这个文件存放在/var/opt/oracle目录下。oraInst.loc文件中包含下面的配置项目：

	Inventory_loc=<oraInventory 所在目录>
	inst_group=<OUI 安装 ORACLE 的操作系统组>
	
例如：

	[oracle@dbtest oracle]$ cat /etc/oraInst.loc 
	inventory_loc=/u01/app/oraInventory
	inst_group=oinstall
	
这个inst_group参数十分重要，它会在link Oracle映像的时候被使用，如果这个参数设置错了，那么link出来的Oracle映像就无法被正常使用了。

在全局Inventory中定义了所有Oracle HOME的情况，这个文件就是ContentsXML目录下的Inventory.xml：

	[oracle@dbtest ContentsXML]$ cat inventory.xml 
	<?xml version="1.0" standalone="yes" ?>
	<!-- Copyright (c) 1999, 2009, Oracle. All rights reserved. -->
	<!-- Do not modify the contents of this file by hand. -->
	<INVENTORY>
	<VERSION_INFO>
	   <SAVED_WITH>11.2.0.1.0</SAVED_WITH>
	   <MINIMUM_VER>2.1.0.6.0</MINIMUM_VER>
	</VERSION_INFO>
	<HOME_LIST>
	<HOME NAME="OraDb11g_home1" LOC="/u01/app/oracle/product/11.2.0/db_1" TYPE="O" IDX="1"/>
	</HOME_LIST>
	</INVENTORY>
	
在ORACLE_HOME下面也有一个Inventory目录，这个目录就是我们平时说的Local Inventory。这个Inventory是本地的，每个ORACLE_HOME所独有的。它记录了本ORACLE_HOME中OUI安装的组件的信息。

## 2. 口令文件

口令文件一般来说放在`$ORACLE_HOME/dbs`目录下，在Windows平台下面，这个文件是在`$ORACLE_HOME/database`目录下。

Oracle数据库的口令文件存放有超级用户的口令及其他特权用户的用户名／口令。在创建一个数据库的时侯，在$ORACLE_HOME/dbs目录下会自动创建一个与之对应的口令文件。此文件是进行初始数据库管理工作的基础。在此之后，管理员也可以根据需要，使用工具ORAPWD手工创建口令文件。

默认安装下，最初的口令文件中只包含 sys 账号的信息:

	[oracle@dbtest dbs]$ strings orapworcl
	]\[Z
	ORACLE Remote Password file
	INTERNAL
	769C0CD849F9B8B2
	5638228DAF52805F
	SYSTEM
	D4DF7931AB130E37
	B}dl
	
这时候如果想把 system 账号设置为 sysdba 权限，我们来看看口令文件有什么变化：

	SQL> grant sysdba to system;
	Grant succeeded.
	
	[oracle@dbtest dbs]$ strings orapworcl
	]\[Z
	ORACLE Remote Password file
	INTERNAL
	769C0CD849F9B8B2
	5638228DAF52805F
	SYSTEM
	D4DF7931AB130E37
	B}dl
	
这个文件中包含了system这个账号。同样我们也可以给其他账号分配sysdba权限。比如我们授予scott账号sysdba权限，授权后，在口令文件中就保留了scott账号的密码信息。这样scott账号就可以在数据库没有启动时进行鉴权了。

## 3. 参数文件

参数文件一般来说放在`$ORACLE_HOME/dbs`目录下，在Windows平台下面，这个文件是在`$ORACLE_HOME/database`目录下。早期的Oracle数据库的参数文件称为PFILE，从Oracle9i开始，引入了服务器参数文件spfile。和pfile不同，spfile采用了一种二进制的方式，同时保留了对原有的文本参数文件的支持。Oracle启动的时候会按照如下顺序查找参数文件：

- $ORACLE_HOME/dbs/spfile\<oracle_sid\>.ORA
- $ORACLE_HOME/dbs/spfile.ora
- $ORACLE_HOME/dbs/init\<oracle_sid\>.ora

实际上，spfile也不完全是二进制的，只是在原有的pfile基础上加入了一些二进制的管理和校验信息，直接编辑spfile，可以取出其中的参数配置的所有信息。

在数据库启动的时候，数据库会根据搜索路径自动查找参数文件。如果找据库启动会失败。如果需要，可以使用下面的方法指定一个启动参数文件：

	sql>startup pfile=$ORACLE_HOME/dbs/init.ora;
	
采用服务器参数文件后，参数文件的修改就相对容易了一些。可以通过Oracle提供的指令修改:

	ALTER SYSTEM SET <PARAMETER>=<VALUE> SCOPE='SPFILE';
	
于习惯于修改文件的人，可以使用下面方法实现参数修改:

	create pfile='xxxxx' from spfile='xxxx';
	create spfile='xxxxx' from pfile='xxxx';

## 4. 控制文件

控制文件是Oracle数据库中十分重要的文件，Oracle数据库启动时，首先会去读参数文件，读了参数文件，实例所需要的共享内存区和后台进程就可以启动了，这就是数据库实例启动的nomount阶段。完成这个步骤以后，就需要通过参数文件中的control_files参数，找到数据库的控制文件，然后打开控制文件，对控制文件进行校验。这就是Oracle数据库实例启动过程中的Mount阶段。

控制文件中包含了Oracle数据库中十分重要的信息，其中包括整个数据库的物理结构、所有数据文件、REDOLOG文件等的信息。当然控制文件中还包含了一些其他的重要信息，比如归档模式下的日志归档情况、rman备份时的catalog信息等。

## 5. 在线日志文件

在线日志文件即REDO LOG文件，“在线”这两个字是用于和归档日志区分的。在线日志是数据库中十分重要的文件，主要用于记录数据库的变更信息。Oracle使用在线日志文件记录数据库变更信息的目的是，当数据库实例宕掉的时候，可以通过在线日志文件中记录的信息进行恢复。

在线日志文件的存在，解决了数据库实例突然宕掉或者服务器宕机后的系统恢复问题。有了在线日志文件，就不用害怕Oracle数据库突然宕掉后数据库实例无法自动修复了，因为它的固有机制可以确保数据库完整恢复。

## 6. 数据文件

数据文件是存储Oracle数据库中的数据的，也是Oracle数据库中最为核心的文件。Oracle数据库中的表、索引等都是记录在数据文件中的。其中系统表空间包含的数据文件里保存了数据库的元数据(metadata)，这部分数据是十分关键的，如果metadata出现故障，那么我们在访问数据库的数据时就会发生问题。

数据文件中还有一类特殊的文件，即临时文件，一般来说，临时文件属于临时表空间。临时文件是Oracle存放临时性数据的，比如排序数据、临时表。一旦数据库重启，临时文件将会丢失。因此，我们不能把永久性的表和索引存放在临时文件中。

## 7. 归档日志文件

归档日志文件是用于长期保存的，它是在线日志的离线拷贝版本，当在线日志切换的时候，ARCH进程就会将这个刚刚关闭的在线日志文件的内容复制到磁盘上，长期保存。归档日志的主要用途是用于数据库的恢复操作。进行数据库完全恢复或者不完全恢复的时候，需要将备份的数据文件恢复到硬盘上，然后通过归档日志将其前滚到所需要的时间点。

在设置了逻辑复制的环境中，归档日志也有可能用来进行挖掘，从而生成LCR(逻辑变化记录)，因此在配置了STREAMS、GOLDENGATE等逻辑复制的环境中，归档日志需要在磁盘上存储更长的时间，以便于逻辑复制使用。在这种环境中，保留5日以上的归档日志是十分必要的，如果你的存储空间足够大，请给予归档日志更大的存储空间，并且这些归档日志的删除策略也要做适当的调整，不能由备份软件自动删除，而是要通过一个定时任务，删除几天前的数据。