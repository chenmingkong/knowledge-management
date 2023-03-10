## mysql查询逻辑

![在这里插入图片描述](https://img-blog.csdnimg.cn/20210301233126474.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L2tvbmdtaW5neGlhb3hpYW8=,size_16,color_FFFFFF,t_70)

- 最上层是服务端，与其他c/s服务类似，管理着连接处理、授权认证、安全等。
- 第二层包含了Mysql的核心服务功能，如查询解析、分析、优化、缓存以及内置函数。还有跨存储引擎的功能也在这一层：存储过程、触发器、视图等。
- 第三层是存储引擎层。这层是Mysql适应性广的根本原因，存储引擎负责了Mysql中数据的存储和提取。服务器通过API于存储引擎进行通信，接口屏蔽了存储引擎之间的差异，使得存储引擎相对于上层的查询过程透明了。

常用的存储引擎有：InnoDB和MyISAM

- InnoDB: 适用数据一致性高，支持排序，支持范围查询的场景。

支持事务支持行锁，间隙锁的使用，使得InnoDB不仅可以锁定涉及的行，还会对索引的间隙进行锁定，防止了幻读自动崩溃恢复特性实现了四个标准的隔离级别，默认隔离级别为 REPEATABLE READ (可重复读)。使用mvcc多版本控制来支持高并发由于支持事务使得可以实现真正的热备份，不用停止写入便能备份数据

- MyISAM：适用于读多写少的业务，如工作岗位类型，类目相关信息表。

表压缩全文索引空间函数仅支持表锁

## MySQL 中的 information_schema 数据库

information_schema 用于存储数据库元数据(关于数据的数据)，例如数据库名、表名、列的数据类型、访问权限等。

information_schema 中的表实际上是视图，而不是基本表，因此，文件系统上没有与之相关的文件。

## innodb如何存储表

（1）MySQL 使用 InnoDB 存储表时，会将表的定义和数据索引等信息分开存储，其中前者存储在 .frm文件中，后者存储在 .ibd文件中，这一节就会对这两种不同的文件分别进行介绍。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20210301232556915.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L2tvbmdtaW5neGlhb3hpYW8=,size_16,color_FFFFFF,t_70)

（2）InnoDB 存储引擎中的 B+ 树索引