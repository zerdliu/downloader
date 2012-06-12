
# downloader
是一个数据下载脚本。依据配置文件下载数据，或者常驻内存更新数据

## 基调

### 整体考虑：便于扩容和全量部署--数据传输的去中心化

去中心化（由推改拉）的优势和劣势。模块可以通过安装包的方式进行安装和环境搭建。便于扩展。每一个节点都是自主的，不需要中心的控制。下载逻辑和配置文件都很简单。
劣势是可控度降低。比如监控报警量会比较多，无法控制下载顺序等。


### 部署时的数据下载和动态更新的数据下载的逻辑合二为一

部署时的数据下载：

	perl ./deploy_script/downloader/bin/downloader.pl -f ./bin/bin.yaml -m ftp

注：程序通过ftp下载的主要原因是QA的机器没有起gingko

部署时的数据下载：

	perl ./deploy_script/downloader/bin/downloader.pl -f ./data/data.yaml -l 50 --threshold=10

注：阈值的10M是可以调整的，可以根据实际情况改为50M或者100M

程序启动后的动态数据更新：

	perl ./deploy_script/downloader/bin/${program_name} --yaml-file=./data/data.yaml --threshold=5 --daemon --download-rate=40 --data-type=dynamic --interval=300

注：以上的信息写在downloader.pl_control里面，为什么选择长参，而不是短参。原因是supervise也可以传参数，使用短参，会导致downloader的参数失效。在其他的使用场景中也要注意！！


## 遗留问题、技术选择和之后的一些考虑


	discount_ratio.txt_1:
	   type: static
	   source: data-im.baidu.com:/home/work/var/CI_DATA/im/static/discount_ratio.txt/discount_ratio.txt.8
	   deploy_path: ./data/auction/discount_ratio.txt


	label:
	   type:
	   source:
	   deploy_path:
	   postfix_command:

  - 其中label的信息是冗余的（而且容易改错，或者改的和本意毫无关联），原有的设计时不使用label的标识，之所以保留是为了让fc_config能够更容易处理。这块是在未来可以变动的。
  - 程序的正常运行依赖于downloader对于动态数据的更新，程序启动必须同时启动downloader（在./deploy_script/donwloader/bin/downloader.pl_control）,目前没有整合到模块启动脚本中。
  - 目前data.yaml的地址中上游写的是mfs的地址。不是最根本的数据的“源”，导致op仍然需要维护一个从外界到mfs的一个downloader的配置。

## 使用方法

### 基本参数介绍

目前downloader被部署在模块目录下，即~/module/deploy_script/downloader

	perl ./deploy_script/downloader/bin/downloader.pl -f ./data/data.yaml

必须要指定一个yaml格式的文件,其中描述了需要下载的文件的信息

	-f --yaml-file        input yaml file

### yaml文件格式介绍


### 扩展参数介绍

程序被调用时首先进行yaml文件的格式检查。目前的主要检查内容为：yaml格式中label是否重复；deploy_name是否重复和被包含；是否都包含必要的字段。test也可以单独被调用。

	-t --test             run as test , check yaml file format

可以控制文件下载的并发度。默认为3个线程同时进行下载（分别下载3个文件）

	-p --parallel         parallel number when download files 
    
可以采用两种底层工具进行数据下载： ftp和gingko（p2p）

	-m --method           get file method: ftp|gingko

数据分为两种类型（逻辑上），static和dynamic，static就是yaml中所写的地址中的数据是不变化的，dynamic是地址中的文件是不断更新的。

	--data-type           static|dynamic

对于yaml文件中数据较多的情况，单独指定ftp或者gingko都不能完全解决问题。采用threshold设定阈值，小于此阈值的采用ftp下载，大于此阈值的采用gingko下载。优化了下载速度和对上游中心的带宽压力。

	--threshold           threshold for ftp or gingko . below threshold use ftp , above threshold use gingko, default:0 , unit: M

可以限制下载速率，默认为10M/s

	-l --download-rate    limit rate when download. default:10 , unit:M

可以对下载的数据进行md5验证，默认不验证

	--check-md5           check md5

### 两种运行模式

downloader有两种运行方式，1.是在部署是进行数据获取，如上述命令；2.是程序启动后负责运行时的数据动态更新（daemon），即程序内部是一个大循环，每隔interval时间检查一次数据是否更新，并进行下载。

	--daemon              run as daemon
	-i --interval         sleep time between each instance when run as daemon

常驻内存的运行方式具体参见bin/downloader.pl_control

### 其他功能

为支持特殊情况和QA测试，方便调整wget和gingko的参数，为downloader增加两个参数，便于向wget和gingko传递特殊参数

	--wget-args            
	--gingko-args          


