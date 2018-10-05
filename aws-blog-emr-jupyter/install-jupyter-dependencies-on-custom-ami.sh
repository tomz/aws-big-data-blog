export NPROC=$(nproc)
export RELEASE=$(cat /etc/system-release)
export REL_NUM=$(ruby -e "puts '$RELEASE'.split.last")
export APACHE_SPARK_VERSION="2.3.0"
export NODE_PATH='/usr/lib/node_modules'


sudo yum update -y
sudo yum install -y xorg-x11-xauth.x86_64 xorg-x11-server-utils.x86_64 xterm libXt libX11-devel libXt-devel libcurl libcurl-devel git graphviz cyrus-sasl cyrus-sasl-devel readline readline-devel gnuplot
sudo yum install --enablerepo=epel -y nodejs npm zeromq3 zeromq3-devel
sudo npm config set strict-ssl false
sudo npm config set registry http://registry.npmjs.org/
sudo yum install -y gcc-c++ patch zlib zlib-devel
sudo  yum install -y libyaml-devel libffi-devel openssl-devel make
sudo yum install -y bzip2 autoconf automake libtool bison iconv-devel sqlite-devel
sudo yum install docker -y

sudo npm install -g --unsafe-perm inherits configurable-http-proxy

sudo npm install -g --unsafe-perm stats-analysis decision-tree machine_learning limdu synaptic node-svm lda brain.js scikit-node classifier
sudo npm install -g --unsafe-perm ijavascript d3 lodash plotly jp-coffeescript
#sudo ijs --ijs-install=global
#sudo jp-coffee --jp-install=global


#sudo yum install openmpi openmpi-devel -y
#sudo ln -s /usr/lib64/openmpi/bin/mpicxx /usr/bin/
#sudo ln -s /usr/lib64/openmpi/bin/mpirun /usr/bin/
#sudo ln -s /usr/lib64/openmpi/bin/mpiexec /usr/bin/
#sudo ln -s /usr/lib64/openmpi/bin/mpicc /usr/bin/
#sudo ln -s /usr/lib64/openmpi/bin/mpic++ /usr/bin/
#sudo ln -s /usr/lib64/openmpi/bin/ompi_info /usr/bin/
wget https://www.open-mpi.org/software/ompi/v1.10/downloads/openmpi-1.10.3.tar.gz
tar xvfz openmpi-1.10.3.tar.gz 
cd openmpi-1.10.3
./configure --prefix=/usr/local/mpi
make -j all
sudo make install
cd ..
rm openmpi-1.10.3.tar.gz
sudo ln -s /usr/local/mpi/bin/mpicxx /usr/bin/
sudo ln -s /usr/local/mpi/bin/mpirun /usr/bin/
sudo ln -s /usr/local/mpi/bin/mpiexec /usr/bin/
sudo ln -s /usr/local/mpi/bin/mpicc /usr/bin/
sudo ln -s /usr/local/mpi/bin/mpic++ /usr/bin/
sudo ln -s /usr/local/mpi/bin/ompi_info /usr/bin/


wget https://github.com/google/protobuf/archive/v3.1.0.tar.gz
tar xvfz v3.1.0.tar.gz 
cd protobuf-3.1.0/
./autogen.sh
./configure CFLAGS=-fPIC CXXFLAGS=-fPIC --disable-shared --prefix=/usr/local/protobuf-3.1.0
make -j $NPROC
sudo make install
cd ..
rm v3.1.0.tar.gz


sudo yum install python36 python36-devel -y
#sudo yum install python35 python35-devel -y
#sudo yum install python34 python34-devel -y
sudo yum install python36-setuptools -y
sudo easy_install-3.6 pip
sudo python3 -m pip install --upgrade pip

sudo yum install python27-devel -y
sudo update-alternatives --set python /usr/bin/python2.7
sudo python -m pip install --upgrade pip

sudo python -m pip install PrettyTable
sudo python -m pip install awscli -U

sudo yum install boost boost-devel -y

sudo yum install -y R R-devel -y

# Oracle JVM not working as well as openjvm
#sudo wget --no-cookies --header "Cookie: gpw_e24=xxx; oraclelicense=accept-securebackup-cookie;" http://download.oracle.com/otn-pub/java/jdk/8u171-b11/512cd62ec5174c3487ac17c61aaa89e8/jdk-8u171-linux-x64.rpm
#sudo rpm -i jdk-8u171-linux-x64.rpm 
#sudo ln -s /usr/java/jdk1.8.0_171-amd64/jre /etc/alternatives/jre
#sudo ln -s /usr/java/jdk1.8.0_171-amd64 /etc/alternatives/jdk

sudo yum install java-1.8.0-openjdk java-1.8.0-openjdk-devel -y
sudo update-alternatives --set java /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/java
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.171-7.b10.37.amzn1.x86_64

curl https://bintray.com/sbt/rpm/rpm | sudo tee /etc/yum.repos.d/bintray-sbt-rpm.repo
sudo yum install sbt -y

git clone https://github.com/apache/incubator-toree.git
cd incubator-toree/
git pull
make -j $NPROC dist
sed -i "s/docker run -t/sudo docker run -t/" Makefile
sudo service docker start
make clean release APACHE_SPARK_VERSION=$APACHE_SPARK_VERSION
cd ..

sudo yum install -y automake fuse fuse-devel libxml2-devel
git clone https://github.com/s3fs-fuse/s3fs-fuse.git
cd s3fs-fuse/
ls -alrt
./autogen.sh
./configure
make -j $NPROC
sudo make install
sudo su -c 'echo user_allow_other >> /etc/fuse.conf'
cd ..

git clone https://github.com/danielfrg/s3contents.git

# BigDL
wget https://s3.amazonaws.com/tomzeng/maven/apache-maven-3.3.3-bin.tar.gz
tar xvfz apache-maven-3.3.3-bin.tar.gz
sudo mv apache-maven-3.3.3 /opt/maven
sudo ln -s /opt/maven/bin/mvn /usr/bin/mvn


cd ~/
wget https://julialang-s3.julialang.org/bin/linux/x64/0.6/julia-0.6.2-linux-x86_64.tar.gz
tar xvfz julia-0.6.2-linux-x86_64.tar.gz
cd julia-d386e40c17
sudo cp -pr bin/* /usr/bin/
sudo cp -pr lib/* /usr/lib/
#sudo cp -pr libexec/* /usr/libexec/
sudo cp -pr share/* /usr/share/
sudo cp -pr include/* /usr/include/
cd ..
rm julia-0.6.2-linux-x86_64.tar.gz

export JULIA_PKGDIR=/usr/share/julia/site
julia -e 'Pkg.init()'
julia -e 'Pkg.add("IJulia")'
julia -e 'Pkg.add("RDatasets");Pkg.add("Gadfly");Pkg.add("DataFrames");Pkg.add("PyPlot")'
# Julia's Spark support does not support Spark on Yarn yet
# install Spark for Julia
export BUILD_SPARK_VERSION=$APACHE_SPARK_VERSION
julia -e 'Pkg.clone("https://github.com/dfdx/Spark.jl"); Pkg.build("Spark"); Pkg.checkout("JavaCall")'


wget https://cache.ruby-lang.org/pub/ruby/2.5/ruby-2.5.0.tar.gz
tar xvzf ruby-2.5.0.tar.gz
cd ruby-2.5.0
./configure --prefix=/usr
sudo make install
sudo gem install rbczmq iruby -N
sudo gem install presto-client -N
sudo gem install awesome_print gnuplot rubyvis nyaplot -N
cd ..
rm ruby-2.5.0.tar.gz

git clone https://github.com/intel-analytics/BigDL.git
cd BigDL/
export MAVEN_OPTS="-Xmx2g -XX:ReservedCodeCacheSize=512m"
export BIGDL_HOME=/mnt/BigDL
export BIGDL_VER="0.6.0-SNAPSHOT"
bash make-dist.sh -P spark_2.x,scala_2.11
#mkdir /tmp/bigdl_summaries
#/usr/local/bin/tensorboard --debug INFO --logdir /tmp/bigdl_summaries/ > /tmp/tensorboard_bigdl.log 2>&1 &
cd ..


# graphframes, the generated jar file is in /home/ec2-user/graphframes/target/scala-2.11/graphframes-assembly-0.6.0-SNAPSHOT-spark2.3.jar
git clone https://github.com/graphframes/graphframes.git
cd graphframes/
build/sbt assembly


# torch
#git clone https://github.com/torch/distro.git torch-distro
#cd torch-distro
#git pull
#./install-deps
#./install.sh -b
#export PATH=$PATH:/mnt/torch-distro/install/bin
#source ~/.profile
#luarocks install lzmq
#luarocks install gnuplot
#cd ..
#git clone https://github.com/facebook/iTorch.git
#cd iTorch
#sudo env "PATH=$PATH:/usr/local/bin" luarocks make
#sudo chown -R $USER $(dirname $(ipython locate profile))
#cd ..

sudo python27 -m pip install jupyter
sudo python36 -m pip install jupyter
sudo python27 -m pip install argparse cheetah oauth pyserial || true # does not work for python3
sudo python36 -m pip install argparse cheetah oauth pyserial || true # does not work for python3

export CPU_GPU="cpu" # "cpu" or "gpu" for wheel intall
export GPUU="" # "" or "-gpu"
#TF_BINARY_URL_PY3="https://storage.googleapis.com/tensorflow/linux/$CPU_GPU/tensorflow$GPUU-1.8.0-cp34-cp34m-linux_x86_64.whl"
#TF_BINARY_URL="https://storage.googleapis.com/tensorflow/linux/$CPU_GPU/tensorflow$GPUU-1.8.0-cp27-none-linux_x86_64.whl"
sudo python36 -m pip install tensorflow$GPUU #$TF_BINARY_URL_PY3
sudo python27 -m pip install tensorflow$GPUU #$TF_BINARY_URL

sudo python27 -m pip install http://download.pytorch.org/whl/cpu/torch-0.4.0-cp27-cp27mu-linux_x86_64.whl
sudo python27 -m pip install torchvision
#sudo python35 -m pip install http://download.pytorch.org/whl/cpu/torch-0.4.0-cp35-cp35m-linux_x86_64.whl 
#sudo python35 -m pip install torchvision
sudo python36 -m pip install http://download.pytorch.org/whl/cpu/torch-0.4.0-cp36-cp36m-linux_x86_64.whl 
sudo python36 -m pip install torchvision


install_python_packages() {

sudo python -m pip install oauth pyserial

sudo python -m pip install jupyter

#sudo python -m pip install pyspark==$APACHE_SPARK_VERSION # the open source pyspark does not have EMR FS support
sudo python -m pip install matplotlib ggplot cython networkx findspark
sudo python -m pip install mrjob pyhive sasl thrift thrift-sasl snakebite --ignore-installed chardet

sudo python -m pip install seaborn || true # fail on python 3
sudo python -m pip install bokeh
sudo python -m pip install scikit-learn numexpr scipy
sudo python -m pip install numpy
sudo python -m pip install pandas || true # fail on python 3
sudo python -m pip install statsmodels || true # fail on python 3

sudo python -m pip install mxnet sagemaker
sudo python -m pip install keras
sudo python -m pip install xgboost lightgbm opencv-python
sudo python -m pip install chainer
# cntk install needs openmpi https://docs.microsoft.com/en-us/cognitive-toolkit/Setup-CNTK-on-Linux
sudo python -m pip install cntk

sudo python -m pip install notebook ipykernel
sudo python -m pip install tornado #==4.5.3 # fix the latest tonardo and asyncio package conflict
sudo python -m ipykernel install
sudo python -m pip install bash_kernel
#sudo python -m bash_kernel.install

sudo python -m pip install sparkmagic
sudo jupyter serverextension enable --py sparkmagic

sudo python -m pip install jupyter_contrib_nbextensions
sudo python -m pip install six
sudo jupyter contrib nbextension install --system
sudo python -m pip install jupyter_nbextensions_configurator
sudo jupyter nbextensions_configurator enable --system
sudo python -m pip install ipywidgets
sudo python3 -m pip install pyeda || true # only work for python3
sudo jupyter nbextension enable --py --sys-prefix widgetsnbextension
sudo python -m pip install gvmagic py_d3
sudo python -m pip install ipython-sql

sudo python -m pip install jupyterlab
#sudo jupyter serverextension enable --py jupyterlab --sys-prefix

sudo python3 -m pip install jupyterhub
sudo python3 -m pip install jinja2 tornado jsonschema pyzmq

sudo python -m pip install dask[complete] distributed || true # fail on python 3.4

sudo python -m pip install awscli

sudo python -m pip install ray horovod


cd s3contents
sudo python setup.py install
cd ..

}

sudo update-alternatives --set python /usr/bin/python3.6
install_python_packages
sudo update-alternatives --set python /usr/bin/python2.7
install_python_packages


# change backend: TKAgg to backend: agg in the following to fix the Tkinter module not found error for seaborn
sudo sed -i "s/backend      : TkAgg/backend      : agg/" /usr/local/lib64/python2.7/site-packages/matplotlib/mpl-data/matplotlibrc
sudo sed -i "s/backend      : TkAgg/backend      : agg/" /usr/local/lib64/python3.6/site-packages/matplotlib/mpl-data/matplotlibrc

sudo /usr/local/bin/jupyter-kernelspec install /usr/local/lib/python3.6/site-packages/sparkmagic/kernels/sparkkernel --name "SparkMagic-Spark"
sudo /usr/local/bin/jupyter-kernelspec install /usr/local/lib/python3.6/site-packages/sparkmagic/kernels/pysparkkernel --name "SparkMagic-PySpark"
sudo /usr/local/bin/jupyter-kernelspec install /usr/local/lib/python3.6/site-packages/sparkmagic/kernels/pyspark3kernel --name "SparkMagic-PySpark3"
sudo /usr/local/bin/jupyter-kernelspec install /usr/local/lib/python3.6/site-packages/sparkmagic/kernels/sparkrkernel --name "SparkMagic-SparkR"

sudo sed -i "s/\"display_name\":\"Spark\"/\"display_name\":\"SparkMagic Scala\"/" /usr/local/share/jupyter/kernels/sparkmagic-spark/kernel.json
sudo sed -i "s/\"display_name\":\"PySpark\"/\"display_name\":\"SparkMagic PySpark\"/" /usr/local/share/jupyter/kernels/sparkmagic-pyspark/kernel.json
sudo sed -i "s/\"display_name\":\"PySpark3\"/\"display_name\":\"SparkMagic PySpark3\"/" /usr/local/share/jupyter/kernels/sparkmagic-pyspark3/kernel.json
sudo sed -i "s/\"display_name\":\"SparkR\"/\"display_name\":\"SparkMagic SparkR\"/" /usr/local/share/jupyter/kernels/sparkmagic-sparkr/kernel.json

sudo sed -i "s/usr\/bin\/python\"/usr\/bin\/python27\"/" /usr/local/share/jupyter/kernels/python2/kernel.json
sudo sed -i "s/usr\/bin\/python\"/usr\/bin\/python36\"/" /usr/local/share/jupyter/kernels/python3/kernel.json


sudo ln -sf /usr/local/bin/ipython /usr/bin/
sudo ln -sf /usr/local/bin/jupyter /usr/bin/


sudo yum install -y xorg-x11-xauth.x86_64 xorg-x11-server-utils.x86_64 xterm libXt libX11-devel libXt-devel libcurl-devel git compat-gmp4 compat-libffi5
sudo yum update R-core R-base R-core-devel R-devel -y

sudo sed -i "s/make/make -j $NPROC/g" /usr/lib64/R/etc/Renviron

export R_REPOS="http://cran.rstudio.com"
sudo R --no-save << R_SCRIPT
    install.packages(c('devtools'), repos="$R_REPOS", quiet = FALSE)
    library(devtools)
R_SCRIPT

# IRKernal setup 
sudo R --no-save << R_SCRIPT
  install.packages(c("curl", "httr", "repr", "IRdisplay", "evaluate", "crayon", "pbdZMQ", "uuid", "digest", "e1071", "party"), repos="$R_REPOS", quiet = TRUE)
R_SCRIPT

sudo R --no-save << R_SCRIPT
  library(devtools)
  devtools::install_github("rstudio/sparklyr")
  install.packages(c('nycflights13', 'Lahman', 'data.table'), repos="$R_REPOS", quiet = TRUE)
R_SCRIPT


# install required packages
sudo R --no-save << R_SCRIPT
install.packages(c('RJSONIO', 'itertools', 'digest', 'Rcpp', 'functional', 'httr', 'plyr', 'stringr', 'reshape2', 'caTools', 'rJava', 'devtools', 'DBI', 'ggplot2', 'dplyr', 'R.methodsS3', 'Hmisc', 'memoise', 'rjson'),
repos="http://cran.rstudio.com")
# here you can add your required packages which should be installed on ALL nodes
# install.packages(c(''), repos="http://cran.rstudio.com", INSTALL_opts=c('--byte-compile') )
R_SCRIPT


# install rmr2 package
pushd .
rm -rf RHadoop
mkdir RHadoop
cd RHadoop
curl --insecure -L https://github.com/RevolutionAnalytics/rmr2/releases/download/3.3.1/rmr2_3.3.1.tar.gz | tar zx
sudo R CMD INSTALL --byte-compile rmr2
popd


# install rhdfs package
curl --insecure -L https://raw.github.com/RevolutionAnalytics/rhdfs/master/build/rhdfs_1.0.8.tar.gz | tar zx
sudo R CMD INSTALL --byte-compile --no-test-load rhdfs

curl --insecure -L https://github.com/RevolutionAnalytics/plyrmr/releases/download/0.6.0/plyrmr_0.6.0.tar.gz | tar zx
sudo R CMD INSTALL --byte-compile plyrmr 

sudo R --no-save << R_SCRIPT
  install.packages(c("base64enc","drat"),repos = "http://cran.us.r-project.org")
  drat::addRepo("cloudyr", "http://cloudyr.github.io/drat")
  install.packages(c("aws.signature","aws.ec2metadata","aws.efs"), repos = c(cloudyr = "http://cloudyr.github.io/drat"))
R_SCRIPT

sudo R --no-save << R_SCRIPT
  install.packages(c("aws.s3","aws.ec2"), repos = c(cloudyr = "http://cloudyr.github.io/drat"))
R_SCRIPT


# RStudio and Shiny servers install
export RSTUDIO_URL="https://download2.rstudio.org/rstudio-server-rhel-1.1.447-x86_64.rpm"
export SHINY_URL="https://download3.rstudio.org/centos6.3/x86_64/shiny-server-1.5.8.909-rh6-x86_64.rpm"

# RStudio
export RSTUDIO_FILE=$(basename $RSTUDIO_URL)
wget $RSTUDIO_URL

# Shiny
export SHINY_FILE=$(basename $SHINY_URL)
wget $SHINY_URL


# run the following in the bootstrap script
#sudo yum install --nogpgcheck -y /home/ec2-user/$RSTUDIO_FILE
#sudo yum install --nogpgcheck -y /home/ec2-user/$SHINY_FILE

#sudo R --no-save <<R_SCRIPT
#  install.packages(c('shiny','rmarkdown'),
#  repos="http://cran.rstudio.com")
#R_SCRIPT

#sudo start rstudio-server
#sudo start shiny-server


# default to Python 2.7
sudo update-alternatives --set python /usr/bin/python2.7



