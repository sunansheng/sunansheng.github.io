---
layout: post
title: Oracle 数据库的关闭
categories: [Oracle]
tags: 关闭
---

## 数据库的关闭 

数据库的启动，通常只需要一个命令STARTUP就完成了，实际上在后台Oracle是通过NOMOUNT、MOUNT、OPEN这3个步骤来完成的；将这个过程逆向过来，那么实际上当通过SHUTDOWN来关闭数据库时，实际上数据库也就经历了CLOSE、DISMOUNT、SHUTDOWN三个步骤。

## 1. 数据库关闭的步骤

数据库关闭的分步骤操作： 

	SQL> alter database close;
	alter database close

注意Close数据库仅允许在没有连接的情况下进行，否则可能遇到如下错误

	ERROR at line 1:
	ORA-01093: ALTER DATABASE CLOSE only permitted with no sessions connected
	
接下来可以将数据库卸载：

	SQL> alter database dismount; 
	Database altered. 

最后一个步骤是彻底关闭数据库实例，可以通过发出 shutdown 命令完成： 

	SQL> shutdown; 
	ORA -01507: database not mounted 
	 
	ORACLE instance shut down. 
	
 
在使用shutdown 命令关闭数据库时，还有几个可选参数，这几个参数分别是 normal 、immediate、transactional、abort。 

## 2. 几种关闭方式的对比

### 2.1 SHUTDOWN NORMAL
shutdow nnormal是数据库关闭shutdown命令的缺省选项，当我们执行shutdown时，Oracle即以正常方式关闭数据库。发出该命令后，任何新的连接都将不再允许连接到数据库，但是在数据库关闭之前，Oracle需要等待当前连接的所有用户都从数据库中退出。

采用这种方式关闭数据库，在下一次启动时不需要进行任何的实例恢复，但是由于Normal方式要等所有用户断开连接后才能关闭数据库，所以等待时间可能超长；在生产环境中，**这种方式几乎无法关闭有大量用户连接的数据库，所以很少被采用。**

### 2.2 SHUTDOWN IMMEDIATE

**shutdown immediate方式是最为常用的一种关闭数据库的方式**，使用这个命令时，当前正在被Oracle处理的事务立即中断，未提交的事务将全部回滚，系统不等待连接到数据库的用户退出，强制断开所有的连接用户。然后执行检查点，将变更数据全部写回数据文件，关闭数据库。使用这种方式关闭数据库，在下次启动数据库时不需要进行实例恢复，是一种安全的数据库关闭方式。
 
但是注意，如果数据库系统繁忙，当前有大量事务执行(甚至是大事务正在处理)，那么使用此选项关闭数据库也可能需要大量时间。

### 2.3 SHUTDOWN ABORT

**shutdown abort是最不推荐采用的关闭数据库的方法**，使用改选项，数据库会立即终止所有用户连接、中断所有事务、立即关闭数据库，使用这种方式关闭数据库，未完成事务不会回滚，数据库也不会执行检查点，所以在下次启动时，数据库必须执行实例恢复，实例恢复可能会需要大量时间，数据库的启动因此可能需要等候很长时间。
 
ABORT的方式关闭数据库，就类似于数据库服务器突然断电，可能会导致不一致的情况出现，所以除非不得已，轻易不要使用这种方式关闭数据库。那么在什么情况下需要使用shutdown abort方式关闭数据库呢？以下是一些常见的场景：

- 数据库或应用异常，其他方式无法关闭数据库； 
- 因为马上到来的断电或其他维护情况，需要快速关闭数据库； 
- 启动异常后需要重新尝试启动； 
- 当使用 shutdown Immediate 无法关闭时； 
- 需要快速重新启动数据库； 
- shutdown 超时或异常。 

除了异常情况之外，有时候需要快速重新启动数据库，很多人习惯用ABORT方式来进行操作，但是需要注意的是，ABORT之后重启数据库需要进行恢复，启动的时间可能很长，所以如果时间允许，可以在关闭数据库之前执行一次Checkpoint，如alter system checkpoint，如果此后再使用ABORT关闭数据库，那么在下次启动恢复时，需要恢复的数据就可以减少，当然如果能够不适应ABORT方式是最好的。

如果关闭过程被打断，数据库都可能陷于两种状态：一种是正常状态，可以继续运行；另一种是未知状态，数据库无法正常运行。如果数据库无法正常运行，那么此时用户将被迫使用ABORT方式关闭数据库。