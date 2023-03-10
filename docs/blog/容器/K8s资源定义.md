https://blog.51cto.com/andyxu/2329257

# 一、Pod

Kubernetes为每个Pod都分配了唯一的IP地址，称之为Pod IP，一个Pod里的多个容器共享Pod  IP地址。Kubernetes要求底层网络支持集群内任意两个Pod之间的TCP/IP直接通信，这通常采用虚拟二层网络技术来实现，例如Flannel、Open  vSwitch等。因此，在Kubernetes里，一个Pod里的容器与另外主机上的Pod容器能够直接通信。

Pod有两种类型：普通的Pod和静态Pod（Static   Pod），静态Pod不存放在etcd存储里，而是存放在某个具体的Node上的一个具体文件中，并且只在此Node上启动运行。普通的Pod一旦被创建，就会被存储到etcd中，随后会被Kubernetes   Master调度到某个具体的Node上并进行绑定（Binding），该Node上的kubelet进程会将其实例化成一组相关的Docker容器并启动起来。当Pod里的某个容器停止时，Kubernetes会自动检测到这个问题并且重新启动这个Pod（重启Pod里的所有容器）；如果Pod所在的Node宕机，则会将这个Node上的所有Pod重新调度到其他节点上运行。

Pod、容器与Node的关系如下图：

![初识Kubernetes（K8s）：各种资源对象的理解和定义](https://s4.51cto.com/images/blog/201812/12/8198f5ace2255bd4f515e3db6362cd5d.png?x-oss-process=image/watermark,size_16,text_QDUxQ1RP5Y2a5a6i,color_FFFFFF,t_100,g_se,x_10,y_10,shadow_90,type_ZmFuZ3poZW5naGVpdGk=)

Kubernetes里的所有资源对象都可以采用yaml或者JSON格式的文件来定义或描述，下面是一个简单的Pod资源定义文件：

```
apiVersion: v1
kind: Pod
metadata:
  name: myweb
  labels:
    name: myweb
spec:
  containers:
  - name: myweb
    image: kubeguide/tomcat-app: v1
    ports:
    - containerPort: 8080
    env:
    - name: MYSQL_SERVICE_HOST
      value: 'mysql'
    - name: MYSQL_SERVICE_PORT
      value: '3306'
```

kind为pod表明这是一个Pod的定义，metadata里的name属性为Pod的名字，metadata里还能定义资源对象的标签（Label），这里声明myweb拥有一个name=myweb的标签（Label）。Pod里包含的容器组的定义则在spec一节中声明，这里定义了一个名字为myweb，对应镜像为kubeguide/tomcat-app:   v1的容器，该容器注入了名为MYSQL_SERVICE_HOST='mysql'和MYSQL_SERVICE_PORT='3306'的环境变量（env关键字），并且在8080端口（containerPort）上启动容器进程。Pod的IP加上这里的容器端口，就组成了一个新的概念——Endpoint，它代表着此Pod里的一个服务进程的对外通信地址。一个Pod也存在着具有多个Endpoint的情况，比如我们把Tomcat定义为一个Pod时，可以对外暴露管理端口与服务端口这两个Endpoint。

Docker里的Volume在Kubernetes里也有对应的概念——Pod  Volume，Pod Volume有一些扩展，比如可以用分布式文件系统GlusterFS等实现后端存储功能；Pod  Volume是定义在Pod之上，然后被各个容器挂载到自己的文件系统中的。对于Pod Volume的定义我们后面会讲到。

这里顺便提一下Event概念，Event是一个事件的记录，记录了事件的最早产生时间、最后重现时间、重复次数、发起者、类型，以及导致此事件的原因等众多信息。Event通常会关联到某个具体的资源对象上，是排查故障的重要参考信息，当我们发现某个Pod迟迟无法创建时，可以用kubectl  describe pod xxx来查看它的描述信息，用来定位问题的原因。
每个Pod都可以对其能使用的服务器上的计算资源设置限额，当前可以设置限额的计算资源有CPU和Memory两种，其中CPU的资源单位为CPU（Core）的数量，是一个绝对值。
对于容器来说一个CPU的配额已经是相当大的资源配额了，所以在Kubernetes里，通常以千分之一的CPU配额为最小单位，用m来表示。通常一个容器的CPU配额被定义为100-300m，即占用0.1-0.3个CPU。与CPU配额类似，Memory配额也是一个绝对值，它的单位是内存字节数。

对计算资源进行配额限定需要设定以下两个参数：

- Requests：该资源的最小申请量，系统必须满足要求。
- Limits：该资源最大允许使用的量，不能超过这个使用限制，当容器试图使用超过这个量的资源时，可能会被Kubernetes Kill并重启。

通常我们应该把Requests设置为一个比较小的数值，满足容器平时的工作负载情况下的资源需求，而把Limits设置为峰值负载情况下资源占用的最大量。下面是一个资源配额的简单定义：

```
spec:
  containers:
  - name: db
    image: mysql
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

最小0.25个CPU及64MB内存，最大0.5个CPU及128MB内存。

# 二、Label（标签）

Label相当于我们熟悉的“标签”，给某个资源对象定义一个Label，就相当于给它打了一个标签，随后可以通过Label  Selector（标签选择器）查询和筛选拥有某些Label的资源对象，Kubernetes通过这种方式实现了类似SQL的简单又通用的对象查询机制。
Label  Selector相当于SQL语句中的where查询条件，例如，name=redis-slave这个Label  Selector作用于Pod时，相当于select * from pod where pod’s name =  ‘redis-slave’这样的语句。Label  Selector的表达式有两种：基于等式的（Equality-based）和基于集合的（Set-based）。下面是基于等式的匹配例子。
name=redis-slave：匹配所有标签为name=redis-slave的资源对象。
env != production：匹配所有标签env不等于production的资源对象。
下面是基于集合的匹配例子

- name in (redis-master, redis-slave)：匹配所有标签为name=redis-master或者name=redis-slave的资源对象。
- name not in (php-frontend)：匹配所有标签name不等于php-frontend的资源对象。

还可以通过多个Label Selector表达式的组合实现复杂的条件选择，多个表达式之间用“，”进行分隔即可，几个条件之间是“AND”的关系，即同时满足多个条件，例如：

```
name=redis-slave, env!=production
name not in (php-frontend), env!=production
```

以Pod为例，Label定义在metadata中：

```
apiVersion: v1
kind: Pod
metadata:
  name: myweb
  labels:
    app: myweb
```

RC和Service在spec中定义Selector与Pod进行关联：

```
apiVersion: v1
kind: ReplicationController
metadata:
  name: myweb
spec:
  replicas: 1
  selector:
    app: myweb
  template:
  …………
```

Deployment、ReplicaSet、DaemonSet和Job则可以在Selector中使用基于集合的筛选条件：

```
selector:
  matchLabels:
    app: myweb
  matchExpressions:
    - {key: tier, operator: In, values: [frontend]}
    - {key: environment, operator: NotIn, values: [dev]}
```

matchLabels用于定义一组Label，与直接写在Selector中作用相同；matchExpressions用于定义一组基于集合的筛选条件，可用的条件运算符包括：In、NotIn、Exists和DoesNotExist。
如果同时设置了matchLabels和matchExpressions，则两组条件为“AND”关系，即所有条件需要同时满足才能完成Selector的筛选。
Label Selector在Kubernetes中的重要使用场景如下：

- Kube-controller进程通过资源对象RC上定义的Label Selector来筛选要监控的Pod副本的数量，从而实现Pod副本的数量始终符合预期设定的全自动控制流程。
- Kube-proxy进程通过Service的Label Selector来选择对应的Pod，自动建立起每个Service到对应Pod的请求转发路由表，从而实现Service的智能负载均衡机制。
- 通过对某些Node定义特定的Label，并且在Pod定义文件中使用NodeSelector这种标签调度策略，kube-scheduler进程可以实现Pod“定向调度”的特性。

下面举个复杂点的例子，假设我们为Pod定义了3个Label：release、env和role，不同的Pod定义了不同的Label。如下图所示，如果我们设置了“role=frontend”的Label  Selector，则会选取到Node 1和Node 2上的Pod。
![初识Kubernetes（K8s）：各种资源对象的理解和定义](https://s4.51cto.com/images/blog/201812/12/7288a5dd3d0683d40fa07959b40e8be5.png?x-oss-process=image/watermark,size_16,text_QDUxQ1RP5Y2a5a6i,color_FFFFFF,t_100,g_se,x_10,y_10,shadow_90,type_ZmFuZ3poZW5naGVpdGk=)
如果我们设置“release=beta”的Label Selector，则会选取到Node 2和Node 3上的Pod，如下图所示。
![初识Kubernetes（K8s）：各种资源对象的理解和定义](https://s4.51cto.com/images/blog/201812/12/4c2f9ad2c06d184fac94eacebeab1d3a.png?x-oss-process=image/watermark,size_16,text_QDUxQ1RP5Y2a5a6i,color_FFFFFF,t_100,g_se,x_10,y_10,shadow_90,type_ZmFuZ3poZW5naGVpdGk=)
总结：使用Label可以给对象创建多组标签，Label和Label Selector共同构成了Kubernetes系统中最核心的应用模型，使得被管理对象能够被精细地分组管理，同时实现了整个集群的高可用性。

# 三、Replication Controller

RC的作用是声明Pod的副本数量在任意时刻都符合某个预期值，所以RC的定义包括如下几个部分。

- Pod期待的副本数量（replicas）。
- 用于筛选目标Pod的Label Selector。
- 当Pod的副本数量小于预期数量时，用于创建新Pod的Pod模板（template）。

下面是一个完整的RC定义的例子，即确保拥有tier=frontend标签的这个Pod（运行Tomcat容器）在整个Kubernetes集群中始终有三个副本：

```
apiVersion: v1
kind: ReplicationController
metadata:
  name: frontend
spec:
  replicas: 3
  selector:
    tier: frontend
  template:
    metadata:
      labels:
        app: app-demo
        tier: frontend
    spec:
      containers:
      - name: tomcat-demo
        image: tomcat
        imagePullPolicy: IfNotPresent
        env:
        - name: GET_HOSTS_FROM
          value: dns
        ports:
        - containerPort: 80
```

当我们定义了一个RC并提交到Kubernetes集群中后，Master节点上的Controller  Manager组件就得到通知，定期巡检系统中当前存活的目标Pod，并确保目标Pod实例的数量刚好等于此RC的期望值。如果有过多的Pod副本在运行，系统就会停掉多余的Pod；如果运行的Pod副本少于期望值，即如果某个Pod挂掉，系统就会自动创建新的Pod以保证数量等于期望值。
通过RC，Kubernetes实现了用户应用集群的高可用性，并且大大减少了运维人员在传统IT环境中需要完成的许多手工运维工作（如主机监控脚本、应用监控脚本、故障恢复脚本等）。
下面我们来看下Kubernetes如何通过RC来实现Pod副本数量自动控制的机制，假如我们有3个Node节点，在RC里定义了redis-slave这个Pod需要保持两个副本，系统将会在其中的两个Node上创建副本，如下图所示。
![初识Kubernetes（K8s）：各种资源对象的理解和定义](https://s4.51cto.com/images/blog/201812/12/bfe96e26db5bf475b47c44b33a526289.png?x-oss-process=image/watermark,size_16,text_QDUxQ1RP5Y2a5a6i,color_FFFFFF,t_100,g_se,x_10,y_10,shadow_90,type_ZmFuZ3poZW5naGVpdGk=)
假如Node2上的Pod2意外终止，根据RC定义的replicas数量2，Kubernetes将会自动创建并启动一个新的Pod，以保证整个集群中始终有两个redis-slave Pod在运行。
系统可能选择Node1或者Node3来创建一个新的Pod，如下图。
![初识Kubernetes（K8s）：各种资源对象的理解和定义](https://s4.51cto.com/images/blog/201812/12/012a9d02fa7e46ff51f182bc742cd522.png?x-oss-process=image/watermark,size_16,text_QDUxQ1RP5Y2a5a6i,color_FFFFFF,t_100,g_se,x_10,y_10,shadow_90,type_ZmFuZ3poZW5naGVpdGk=)
通过修改RC的副本数量，可以实现Pod的动态缩放（Scaling）功能。
`kubectl scale rc redis-slave --replicas=3`
此时Kubernetes会在3个Node中选取一个Node创建并运行一个新的Pod3，使redis-slave Pod副本数量始终保持3个。

# 四、Replica Set

由于Replication Controller与Kubernetes代码中的模块Replication  Controller同名，同时这个词也无法准确表达它的意思，所以从Kubernetes  v1.2开始，它就升级成了另外一个新的对象——Replica Set，官方解释为“下一代的RC”。它与RC当前存在的唯一区别是：Replica  Set支持基于集合的Label selector（Set-based selector），而RC只支持基于等式的Label  selector（equality-based selector），所以Replica Set的功能更强大。下面是Replica  Set的定义例子（省去了Pod模板部分的内容）：

```
apiVersion: extensions/v1beta1
kind: ReplicaSet
metadata:
  name: frontend
spec:
  selector:
    matchLabels:
      tier: frontend
    matchExpressions:
      - {key: tier, operator: In, values: [frontend]}
  template:
  …………
```

Replica Set很少单独使用，它主要被Deployment这个更高层的资源对象所使用，从而形成一整套Pod创建、删除、更新的编排机制。
RC和RS的特性与作用如下：

- 在大多情况下，我们通过定义一个RC实现Pod的创建过程及副本数量的自动控制。
- RC里包括完整的Pod定义模板。
- RC通过Label Selector机制实现对Pod副本的自动控制。
- 通过改变RC里的Pod副本数量，可以实现Pod的扩容或缩容功能。
- 通过改变RC里Pod模板中的镜像版本，可以实现Pod的滚动升级功能。

# 五、Deployment

Deployment相对于RC的最大区别是我们可以随时知道当前Pod“部署”的进度。一个Pod的创建、调度、绑定节点及在目标Node上启动对应的容器这一完整过程需要一定的时间，所以我们期待系统启动N个Pod副本的目标状态，实际上是一个连续变化的“部署过程”导致的最终状态。
Deployment的典型使用场景有以下几个：

- 创建一个Deployment对象来生成对应的Replica Set并完成Pod副本的创建过程。
- 检查Deployment的状态来看部署动作是否完成（Pod副本的数量是否达到预期的值）。
- 更新Deployment以创建新的Pod（比如镜像升级）。
- 如果当前Deployment不稳定，则回滚到一个早先的Deployment版本。
- 暂停Deployment以便于一次性修改多个Pod Template Spec的配置项，之后再恢复Deployment，进行新的发布。
- 扩展Deployment以应对高负载。
- 查看Deployment的状态，以此作为发布是否成功的指标。
- 清理不再需要的旧版本ReplicaSet。

Deployment的定义与Replica Set的定义类似，只是API声明与Kind类型不同。

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx-deployment
apiVersion: v1
kind: ReplicaSet
metadata:
  name: nginx-repset
```

下面是Deployment定义的一个完整例子：

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      tier: frontend
    matchExpressions:
      - {key: tier, operator: In, values: [frontend]}
  template:
    metadata:
      labels:
        app: app-demo
        tier: frontend
    spec:
      containers:
      - name: tomcat-demo
        image: tomcat
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
```

可以通过命令kubectl get deployment来查看Deployment的信息，其中的几个参数解释如下：

- DESIRED:：Pod副本数量的期望值，即Deployment里定义的Replica。
- CURRENT：当前Replica的值，如果小于DESIRED的期望值，会创建新的Pod，直到达成DESIRED为止。
- UP-TO-DATE：最新版本的Pod的副本数量，用于指示在滚动升级的过程中，有多少个Pod副本已经成功升级。
- AVAILABLE：当前集群中可用的Pod副本数量，即集群中当前存活的Pod数量。

Pod的管理对象，除了RC、ReplicaSet、Deployment，还有DaemonSet、StatefulSet、Job等，分别用于不同的应用场景。

# 六、Horizontal Pod Autoscaler

HPA与RC、Deployment一样，也属于Kubernetes资源对象。通过追踪分析RC或RS控制的所有目标Pod的负载变化情况，来确定是否需要针对性地调整目标Pod的副本数。
HPA有以下两种方式作为Pod负载的度量指标：

- CPUUtilizationPercentage
- 应用程序自定义的度量指标，比如服务在每秒内的相应的请求数（TPS或QPS）。

CPUUtilizationPercentage是一个算术平均值，即目标Pod所有副本自带的CPU利用率的平均值。一个Pod自身的CPU利用率是该Pod当前CPU的使用量除以它的Pod  Request的值，比如我们定义一个Pod的Pod  Request为0.4，而当前Pod的CPU使用量为0.2，则它的CPU使用率为50%，这样我们就可以算出来一个RC或RS控制的所有Pod副本的CPU利用率的算术平均值了。如果某一时刻CPUUtilizationPercentage的值超过80%，则意味着当前的Pod副本数很可能不足以支撑接下来更多的请求，需要进行动态扩容，而当请求高峰时段过去后，Pod的CPU利用率又会降下来，此时对应的Pod副本数应该自动减少到一个合理的水平。
下面是HPA定义的一个具体的例子：

```
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache
  namespace: default
spec:
  maxReplicas: 10
  minReplicas: 2
  scaleTargetRef:
    kind: Deployment
    name: php-apache
  targetCPUUtilizationPercentage: 90
```

通过HPA控制php-apache的Pod副本，当Pod副本的CPUUtilizationPercentage的值超过90%时，会进行自动扩容增加Pod副本的数量，扩容或缩容时Pod的副本数量要介于2-10之间。
除了通过yaml文件来定义HPA对象之外，还可以通过命令的方式创建：
`kubectl autoscale deployment php-apache --cpu-percent=90 --min=1 --max=10`

# 七、StatefulSet

Pod的管理对象RC、Deployment、DaemonSet和Job都是面向无状态的服务，但实际中有很多服务是有状态的，比如Mysql集群、MongoDB集群、ZooKeeper集群等，可以使用StatefulSet来管理有状态的服务。
StatefulSet有如下一些特性：

- StatefulSet里的每个Pod都有稳定、唯一的网络标识，可以用来发现集群内的其他成员。假设StatefulSet的名字叫kafka，那么第1个Pod叫kafka-0，第2个叫kafka-1，以此类推。
- StatefulSet控制的Pod副本的启停顺序是受控的，操作第n个Pod时，前n-1个Pod已经是运行且准备好的状态。
- StatefulSet里的Pod采用稳定的持久化存储卷，通过PV/PVC来实现，删除Pod时默认不会删除与StatefulSet相关的存储卷（为了保证数据的安全）。

StatefulSet除了要与PV卷捆绑使用以存储Pod的状态数据，还要与Headless  Service配合使用，即在每个StatefulSet的定义中要声明它属于哪个Headless Service。Headless  Service与普通Service的区别在于，它没有Cluster IP，如果解析Headless  Service的DNS域名，则返回的是该Service对应的全部Pod的Endpoint列表。StatefulSet在Headless  Service的基础上又为StatefulSet控制的每个Pod实例创建了一个DNS域名，这个域名的格式为：

```
$(podname).$(headless service name)
```

比如一个3节点的kafka的StatefulSet集群，对应的Headless  Service的名字为kafka，StatefulSet的名字为kafka，则StatefulSet里面的3个Pod的DNS名称分别为kafka-0.kafka、kafka-1.kafka、kafka-3.kafka，这些DNS名称可以直接在集群的配置文件中固定下来。

# 八、Service（服务）

**1.概述**

Service其实就是我们经常提起的微服务架构中的一个“微服务”，Pod、RC等资源对象其实都是为它作“嫁衣”的。Pod、RC或RS与Service的逻辑关系如下图所示。

![初识Kubernetes（K8s）：各种资源对象的理解和定义](https://s4.51cto.com/images/blog/201812/12/37378759db298352a6ea78025f75cc33.png?x-oss-process=image/watermark,size_16,text_QDUxQ1RP5Y2a5a6i,color_FFFFFF,t_100,g_se,x_10,y_10,shadow_90,type_ZmFuZ3poZW5naGVpdGk=)

通过上图我们看到，Kubernetes的Service定义了一个服务的访问入口地址，前端的应用（Pod）通过这个入口地址访问其背后的一组由Pod副本组成的集群实例，Service与其后端Pod副本集群之间则是通过Label  Selector来实现“无缝对接”的。而RC的作用实际上是保证Service的服务能力和服务质量始终处于预期的标准。

通过分析、识别并建模系统中的所有服务为微服务——Kubernetes   Service，最终我们的系统由多个提供不同业务能力而又彼此独立的微服务单元所组成，服务之间通过TCP/IP进行通信，从而形成了强大而又灵活的弹性集群，拥有了强大的分布式能力、弹性扩展能力、容错能力。因此，我们的系统架构也变得简单和直观许多。

既然每个Pod都会被分配一个单独的IP地址，而且每个Pod都提供了一个独立的Endpoint（Pod   IP+ContainerPort）以被客户端访问，多个Pod副本组成了一个集群来提供服务，那么客户端如何来访问它们呢？一般的做法是部署一个负载均衡器（软件或硬件），但这样无疑增加了运维的工作量。在Kubernetes集群里使用了Service（服务），它提供了一个虚拟的IP地址（Cluster  IP）和端口号，Kubernetes集群里的任何服务都可以通过Cluster  IP+端口的方式来访问此服务，至于访问请求最后会被转发到哪个Pod，则由运行在每个Node上的kube-proxy负责。kube-proxy进程其实就是一个智能的软件负载均衡器，它负责把对Service的请求转发到后端的某个Pod实例上，并在内部实现服务的负载均衡与会话保持机制。
下面是一个Service的简单定义：

```
apiVersion: v1
kind: Service
metadata:
  name: tomcat-service
spec:
  ports:
  - port: 8080
  selector:
    tier: frontend
```

上述内容定义了一个名为“tomcat-service”的Service，它的服务端口为8080，拥有“tier=frontend”这个Label的所有Pod实例。
很多服务都存在多个端口的问题，通常一个端口提供业务服务，另外一个端口提供管理服务，比如Mycat、Codis等常见中间件。Kubernetes  Service支持多个Endpoint，要求每个Endpoint定义一个名字来区分，下面是tomcat多端口的Service定义样例。

```
apiVersion: v1
kind: Service
metadata:
  name: tomcat-service
spec:
  ports:
  - port: 8080
    name: service-port
  - port: 8005
    name: shutdown-port
  selector:
    tier: frontend
```

多端口为什么需要给每个端口命名呢？这就涉及Kubernetes的服务发现机制了。

**2.Kubernetes的服务发现机制**

每个Kubernetes中的Service都有一个唯一的Cluster IP及唯一的名字，而名字是由我们自己定义的，那我们是否可以通过Service的名字来访问呢？

最早时Kubernetes采用了Linux环境变量的方式来实现，即每个Service生成一些对应的Linux环境变量（ENV），并在每个Pod的容器启动时，自动注入这些环境变量，以实现通过Service的名字来建立连接的目的。
考虑到通过环境变量获取Service的IP与端口的方式仍然不方便、不直观，后来Kubernetes通过Add-On增值包的方式引入了DNS系统，把服务名作为DNS域名，这样程序就可以直接使用服务名来建立连接了。

关于DNS的部署，后续博文我会单独讲解，有兴趣的朋友可以关注我的博客。

**3.外部系统访问Service的问题**

Kubernetes集群里有三种IP地址，分别如下：

- Node IP：Node节点的IP地址，即物理网卡的IP地址。
- Pod IP：Pod的IP地址，即docker容器的IP地址，此为虚拟IP地址。
- Cluster IP：Service的IP地址，此为虚拟IP地址。

外部访问Kubernetes集群里的某个节点或者服务时，必须要通过Node IP进行通信。
Pod IP是Docker Engine根据docker0网桥的IP地址段进行分配的一个虚拟二层网络IP地址，Pod与Pod之间的访问就是通过这个虚拟二层网络进行通信的，而真实的TCP/IP流量则是通过Node IP所在的物理网卡流出的。

Service的Cluster IP具有以下特点：

- Cluster IP仅仅作用于Service这个对象，并由Kubernetes管理和分配IP地址。
- Cluster IP是一个虚拟地址，无法被ping。
- Cluster IP只能结合Service Port组成一个具体的通信端口，供Kubernetes集群内部访问，单独的Cluster IP不具备TCP/IP通信的基础，并且外部如果要访问这个通信端口，需要做一些额外的工作。
- Node IP、Pod IP和Cluster IP之间的通信，采用的是Kubernetes自己设计的一种特殊的路由规则，与我们熟悉的IP路由有很大的区别。

我们的应用如果想让外部访问，最常用的作法是使用NodePort方式。

```
apiVersion: v1
kind: Service
metadata:
  name: tomcat-service
spec:
  type: NodePort
  ports:
  - port: 8080
    nodePort: 31002
  selector:
    tier: frontend
```

NodePort的实现方式是在Kubernetes集群里的每个Node上为需要外部访问的Service开启一个对应的TCP监听端口，外部系统只要用任意一个Node的IP地址+具体的NodePort端口号即可访问此服务。

NodePort还没有完全解决外部访问Service的所有问题，比如负载均衡问题，常用的做法是在Kubernetes集群之外部署一个负载均衡器。

![初识Kubernetes（K8s）：各种资源对象的理解和定义](https://s4.51cto.com/images/blog/201812/12/cceea13a51ed6faab6709667f36d1a27.png?x-oss-process=image/watermark,size_16,text_QDUxQ1RP5Y2a5a6i,color_FFFFFF,t_100,g_se,x_10,y_10,shadow_90,type_ZmFuZ3poZW5naGVpdGk=)

Load balancer组件独立于Kubernetes集群之外，可以是一个硬件负载均衡器，也可以是软件方式实现，例如HAProxy或者Nginx。这种方式，无疑是增加了运维的工作量及出错的概率。

于是Kubernetes提供了自动化的解决方案，如果我们使用谷歌的GCE公有云，那么只需要将type:  NodePort改成type: LoadBalancer，此时Kubernetes会自动创建一个对应的Load  balancer实例并返回它的IP地址供外部客户端使用。其他公有云提供商只要实现了支持此特性的驱动，则也可以达到上述目的。

# 九、Volume（存储卷）

Volume是Pod中能够被多个容器访问的共享目录。Volume定义在Pod上，被一个Pod里的多个容器挂载到具体的文件目录下，当容器终止或者重启时，Volume中的数据也不会丢失。Kubernetes支持多种类型的Volume，例如GlusterFS、Ceph等分布式文件系统。
除了可以让一个Pod里的多个容器共享文件、让容器的数据写到宿主机的磁盘上或者写文件到网络存储中，Kubernetes还提供了容器配置文件集中化定义与管理，通过ConfigMap对象来实现。

Kubernetes支持多种Volume类型，下面我们一一进行介绍。

**1.emptyDir**

emptyDir是在Pod分配到Node时创建的，它的初始内容为空，并且无须指定宿主机上对应的目录文件，它是Kubernetes自动分配的一个目录，当Pod从Node上移除时，emptyDir中的数据也会被永久删除。
emptyDir的用途如下：

- 临时空间，例如用于某些应用程序运行时所需的临时目录，且无须永久保存。
- 长时间任务的中间过程CheckPoint的临时保存目录。
- 一个容器需要从另一个容器中获取数据的目录（多容器共享目录）。

emptyDir的定义如下：

```
template:
  metadata:
    labels:
      app: app-demo
      tier: frontend
  spec:
    volumes:
      - name: datavol
        emptyDir: {}
    containers:
    - name: tomcat-demo
      image: tomcat
      volumeMounts:
        - mountPath: /mydata-data
          name: datavol
      imagePullPolicy: IfNotPresent
```

**2.hostPath**

使用hostPath挂载宿主机上的文件或目录，主要用于以下几个方面：

- 容器应用程序生成的日志文件需要永久保存时，可以使用宿主机的文件系统存储。
- 需要访问宿主机上Docker引擎内部数据时，可以定义hostPath的宿主机目录为docker的数据存储目录，使容器内部应用可以直接访问docker的数据文件。

使用hostPath时，需要注意以下几点：

- 在不同的Node上的Pod挂载的是本地宿主机的目录，如果要想让不同的Node挂载相同的目录，则可以使用网络存储或分布式文件存储。
- 如果使用了资源配额管理，则Kubernetes无法将其在宿主机上使用的资源纳入管理。

hostPath的定义如下：

```
volumes:
- name: "persistent-storage"
  hostPath:
    path: "/data"
```

**3.gcePersistentDisk**

使用这种类型的Volume表示使用谷歌公有云提供的永久磁盘（Persistent Disk，PD）存放数据，使用gcePersistentDisk有以下一些限制条件：

- Node需要是谷歌GCE云主机。
- 这些云主机需要与PD存在于相同的GCE项目和Zone中。

通过gcloud命令创建一个PD：

`gcloud compute disks create --size=500GB --zone=us-centrall-a my-data-disk`

定义gcePersistentDisk类型的Volume的示例如下：

```
volumes:
- name: test-volume
  gcPersistentDisk:
    pdName: my-data-disk
    fsType: ext4
```

**4.awsElasticBlockStore**

与GCE类似，该类型的Volume使用亚马逊公有云提供的EBS Volume存储数据，需要先创建一个EBS Volume才能使用awsElasticBlockStore。
使用awsElasticBlockStore的一些限制条件如下：

- Node需要是AWS EC2实例。
- 这些AWS EC2实例需要与EBS volume存在于相同的region和availability-zone中。
- EBS只支持单个EC2实例mount一个volume。

通过aws ec2 create-volume命令创建一个EBS volume：

`aws ec2 create-volume --availability-zone eu-west-la --size 10 --volume-type gp2`

定义awsElasticBlockStore类型的Volume的示例如下：

```
volumes:
- name: test-volume
  awsElasticBlockStore:
    volumeID: aws://<availability-zone>/<volume-id>
    fsType: ext4
```

**5.NFS**

使用NFS网络文件系统提供的共享目录存储数据时，我们需要在系统中部署一个NFS Server。
定义NFS类型的Volume的示例如下：

```
volumes:
- name: nfs-volume
  nfs:
    server: nfs-server.localhost
    path: "/"
```

**6.其他类型的Volume**

- iscsi：使用iSCSI存储设备上的目录挂载到Pod中。
- flocker：使用Flocker来管理存储卷。
- glusterfs：使用GlusterFS网络文件系统的目录挂载到Pod中。
- rbd：使用Ceph块设备共享存储（Rados Block Device）挂载到Pod中。
- gitRepo：通过挂载一个空目录，并从GIT库clone一个git repository以供Pod使用。
- secret：一个secret volume用于为Pod提供加密的信息，可以将定义在Kubernetes中的secret直接挂载为文件让Pod访问。Secret volume是通过tmfs（内存文件系统）实现的，所以这种类型的volume不会持久化。

# 十、Persistent Volume

上面提到的Volume是定义在Pod上的，属于“计算资源”的一部分，而实际上，“网络存储”是相对独立于“计算资源”而存在的一种实体资源。比如在使用云主机的情况下，我们通常会先创建一个网络存储，然后从中划出一个“网盘”并挂载到云主机上。Persistent  Volume（简称PV）和与之相关联的Persistent Volume Claim（简称PVC）实现了类似的功能。
PV与Volume的区别如下：

- PV只能是网络存储，不属于任何Node，但可以在每个Node上访问。
- PV并不是定义在Pod上的，而是独立于Pod之外定义。

下面是NFS类型PV的yaml定义内容，声明了需要5G的存储空间：

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv003
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  nfs:
    path: /somepath
    server: 172.17.0.2
```

PV的accessModes属性有以下类型：

- ReadWriteOnce：读写权限、并且只能被单个Node挂载。
- ReadOnlyMany：只读权限、允许被多个Node挂载。
- ReadWriteMany：读写权限、允许被多个Node挂载。

如果Pod想申请使用PV资源，则首先需要定义一个PersistentVolumeClaim（PVC）对象：

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myclaim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

然后在Pod的volume定义中引用上述PVC即可

```
volumes:
  - name: mypd
    persistentVolumeClaim:
      claimName: myclaim
```

PV是有状态的对象，它有以下几种状态：

- Available：空闲状态。
- Bound：已经绑定到某个PVC上。
- Released：对应的PVC已经删除，但资源还没有被集群收回。
- Failed：PV自动回收失败。

# 十一、Namespace（命名空间）

通过将Kubernetes集群内部的资源对象“分配”到不同的Namespace中，形成逻辑上分组的不同项目、小组或用户组，便于不同的分组在共享使用整个集群的资源的同时还能被分别管理。

Kubernetes集群在启动后，会创建一个名为“default”的Namespace，通过kubectl可以查看到：

`kubectl get namespaces`

如果不特别指明Namespace，则用户创建的Pod、RC、RS、Service都奖被系统创建到这个默认的名为default的Namespace中。

下面是Namespace的定义示例：

```
apiVersion: v1
kind: Namespace
metadata:
  name: development
```

定义一个Pod，并指定它属于哪个Namespace：

```
apiVersion: v1
kind: Pod
metadata:
  name: busybox
  namespace: development
spec:
  containers:
  - image: busybox
    command:
      - sleep
      - "3600"
    name: busybox
```

使用kubectl get命令查看Pod状态信息时，需要加上--namespace参数，指定查看哪个namespace下的资源对象，不加这个参数则默认查看 default下的资源对象。

`kubectl get pods --namespace=development`

当我们给每个租户创建一个Namespace来实现多租户的资源隔离时，还能结合Kubernetes的资源配额管理，限定不同租户能占用的资源，例如CPU使用量、内存使用量等。

# 十二、Annotation（注解）

Annotation与Label类似，也使用key/value键值对的形式进行定义。不同的是Label具有严格的命名规则，它定义的是Kubernetes对象的元数据（Metadata），并且用于Label   Selector。而Annotation则是用户任意定义的“附加”信息，以便于外部工具进行查找。通常Kubernetes的模块会通过Annotation的方式标记资源对象的一些特殊信息。
使用Annotation来记录的信息如下：

- build信息、release信息、Docker镜像信息等，例如时间戳、release id号、PR号、镜像bash值、docker registry地址等。
- 日志库、监控库、分析库等资源库的地址信息。
- 程序调试工具信息，例如工具名称、版本号等。
- 团队的联系信息，例如电话号码、负责人名称、网址等。

注：本文内容摘自《Kubernetes权威指南：从Docker到Kubernetes实践全接触（纪念版》，并精减了部分内部，而且对部分内容做了相应的调整，可以帮助大家加深对Kubernetes的各种资源对象的理解和定义方法，关注我的博客，跟我一起开启k8s的学习之旅吧。