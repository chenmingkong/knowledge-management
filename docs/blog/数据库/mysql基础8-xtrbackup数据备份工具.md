xtrabackup是Percona公司CTO Vadim参与开发的一款基于InnoDB的在线热备工具，具有开源，免费，支持在线热备，备份恢复速度快，占用磁盘空间小等特点，并且支持不同情况下的多种备份形式。xtrabackup的官方下载地址为http://www.percona.com/software/percona-xtrabackup。

## 备份原理

![在这里插入图片描述](https://img-blog.csdnimg.cn/2021030123171769.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L2tvbmdtaW5neGlhb3hpYW8=,size_16,color_FFFFFF,t_70)

## 常用参数

```
常用选项:  
   --host     指定主机
   --user     指定用户名
   --password    指定密码
   --port     指定端口
   --databases     指定数据库
   --incremental    创建增量备份
   --incremental-basedir   指定包含完全备份的目录
   --incremental-dir      指定包含增量备份的目录   
   --apply-log        对备份进行预处理操作             
     一般情况下，在备份完成后，数据尚且不能用于恢复操作，因为备份的数据中可能会包含尚未提交的事务或已经提交但尚未同步至数据文件中的事务。因此，此时数据文件仍处理不一致状态。“准备”的主要作用正是通过回滚未提交的事务及同步已经提交的事务至数据文件也使得数据文件处于一致性状态。
   --redo-only      不回滚未提交事务
   --copy-back     恢复备份目录
```

## 注意事项

备份过程中会出现`FLUSH TABLES WITH READ` ，即LOCK关闭所有打开的表并使用全局读锁锁定所有数据库的所有表，flush本身速度很快，但是由于锁定之前会等待所有查询和事务结束，因此，如果出现慢查询，会将所有查询和事务进行等待，从而导致数据库查询超时、连接数暴增等情况。

解决策略：flush的时候kill掉所有超过规定时长的慢查询
```
--kill-long-queries-timeout=40
```