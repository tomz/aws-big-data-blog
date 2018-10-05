#!/bin/bash
#
# Copyright 2016-2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License is located at
#
# http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.

set -x -e

# AWS EMR bootstrap script 
# for installing Jupyter notebook on AWS EMR 5+
#
#
# Usage:
# --r - install the IRKernel for R (Sparklyr is installed with this option, but as of 2017-04-05 Sparklyr does not support Spark 2.x yet)
# --sparkmagic - install the SparkMagic kernel
# --toree - install the Apache Toree kernel that supports Scala, PySpark, SQL, SparkR for Apache Spark
# --toree-interpreters - specify Apache Toree interpreters, default is all: "Scala,SQL,SparkR"
# --julia - install the IJulia kernel for Julia
# --bigdl - install Intel's BigDL Deep Learning framework
# --ruby - install the iRuby kernel for Ruby
# --javascript - install the JavaScript and CoffeeScript kernels (only works for JupyterHub for now)
# --dask - install Dask and Dask.distributed, with the scheduler on master instance and the workers on the slave instances
# --ds-packages - install the Python Data Science related packages (scikit-learn pandas numpy numexpr statsmodels seaborn)
# --ml-packages - install the Python Machine Learning related packages (theano keras tensorflow)
# --python-packages - install specific python packages e.g. "ggplot nilean"
# --port - set the port for Jupyter notebook, default is 8888
# --user - create a default user for Jupyterhub
# --password - set the password for Jupyter notebook and JupyterHub
# --localhost-only - restrict jupyter to listen on localhost only, default to listen on all ip addresses for the instance
# --jupyterlab - install JupyterLab
# --jupyterhub - install JupyterHub
# --jupyterhub-port - set the port for JupyterHub, default is 8000
# --no-jupyter - if JupyterHub is installed, use this to disable Jupyter
# --no-jupyterhub - if Jupyter is installed, use this to disable JupyterHub
# --notebook-dir - specify notebook folder, this could be a local directory or a S3 bucket
# --ssl - enable ssl, make sure to use your own cert and key files to get rid of the warning
# --copy-samples - copy sample notebooks to samples sub folder under the notebook folder
# --spark-opts - user supplied Spark options to pass to SPARK_OPTS
# --s3fs - use s3fs instead of s3contents(default) for storing notebooks on s3, s3fs could cause slowness if the s3 bucket has lots of file
# --python3 - install python 3 packages and use python3

# check for master node
IS_MASTER=false
if grep isMaster /mnt/var/lib/info/instance.json | grep true;
then
  IS_MASTER=true
fi

# error message
error_msg ()
{
  echo 1>&2 "Error: $1"
}

# some defaults
RUBY_KERNEL=false
R_KERNEL=false
JULIA_KERNEL=false
SPARKMAGIC_KERNEL=false
TOREE_KERNEL=false
TORCH_KERNEL=false
DS_PACKAGES=false
ML_PACKAGES=false
PYTHON_PACKAGES=""
RUN_AS_STEP=false
NOTEBOOK_DIR=""
NOTEBOOK_DIR_S3=false
JUPYTER_PORT=8887
JUPYTER_PASSWORD="jupyter"
JUPYTER_LOCALHOST_ONLY=false
PYTHON3=false
GPU=false
CPU_GPU="cpu"
GPUU=""
JUPYTER_HUB=true
JUPYTER_HUB_PORT=8007
JUPYTER_HUB_API_PORT=8006
JUPYTER_HUB_IP="*"
JUPYTER_HUB_DEFAULT_USER="jupyter"
NOTEBOOK_OR_LAB="notebook" # notebook or lab
JUPYTER_LAB=false
INTERPRETERS="Scala,SQL,SparkR"  # Scala,SQL,PySpark,SparkR
R_REPOS_LOCAL="file:////mnt/miniCRAN"
R_REPOS_REMOTE="http://cran.rstudio.com"
USE_CACHED_DEPS=false
R_REPOS=$R_REPOS_REMOTE
SSL=false
COPY_SAMPES=false
USER_SPARK_OPTS=""
NOTEBOOK_DIR_S3_S3NB=false
NOTEBOOK_DIR_S3_S3CONTENTS=true
JS_KERNEL=false
NO_JUPYTER=false
INSTALL_DASK=false
APACHE_SPARK_VERSION="2.3.0"
BIGDL=false
MXNET=false
DL4J=false
NPROC=$(nproc)
UPDATE_FLAG=""
USE_SSE=false
KMS_ID=""
GRAPHFRAMES=false

# get input parameters
while [ $# -gt 0 ]; do
    case "$1" in
    --r)
      R_KERNEL=true
      ;;
    --julia)
      JULIA_KERNEL=true
      ;;
    --toree)
      TOREE_KERNEL=true
      ;;
    --sparkmagic)
      SPARKMAGIC_KERNEL=true
      ;;
    --graphframes)
      GRAPHFRAMES=true
      ;;
    --torch)
      #TORCH_KERNEL=true
      ;;
    --javascript)
      JS_KERNEL=true
      ;;
    --ds-packages)
      DS_PACKAGES=true
      ;;
    --ml-packages)
      ML_PACKAGES=true
      ;;
    --python-packages)
      shift
      PYTHON_PACKAGES=$1
      ;;
    --bigdl)
      BIGDL=true
      ;;
    --mxnet)
      MXNET=true
      ;;
    --dl4j)
      DL4J=true
      ;;
    --ruby)
      RUBY_KERNEL=true
      ;;
    --gpu)
      #GPU=true
      #CPU_GPU="gpu"
      #GPUU="_gpu"
      ;;
    --run-as-step)
      RUN_AS_STEP=true
      ;;
    --port)
      shift
      JUPYTER_PORT=$1
      ;;
    --user)
      shift
      JUPYTER_HUB_DEFAULT_USER=$1
      ;;
    --password)
      shift
      JUPYTER_PASSWORD=$1
      ;;
    --localhost-only)
      JUPYTER_LOCALHOST_ONLY=true
      JUPYTER_HUB_IP=""
      ;;
    --jupyterlab)
      JUPYTER_LAB=true
      NOTEBOOK_OR_LAB="lab"
      ;;
    --jupyterhub)
      JUPYTER_HUB=true
      ;;
    --jupyterhub-port)
      shift
      JUPYTER_HUB_PORT=$1
      ;;
    --jupyterhub-api-port)
      shift
      JUPYTER_HUB_API_PORT=$1
      ;;
    --notebook-dir)
      shift
      NOTEBOOK_DIR=$1
      ;;
    --copy-samples)
      COPY_SAMPLES=true
      ;;
    --toree-interpreters)
      shift
      INTERPRETERS=$1
      ;;
    --cached-install)
      #USE_CACHED_DEPS=true
      #R_REPOS=$R_REPOS_LOCAL
      ;;
    --no-cached-install)
      USE_CACHED_DEPS=false
      R_REPOS=$R_REPOS_REMOTE
      ;;
    --no-jupyter)
      NO_JUPYTER=true
      ;;
    --no-jupyterhub)
      JUPYTER_HUB=false
      ;;
    --ssl)
      SSL=true
      ;;
    --update-python-packages)
      UPDATE_FLAG="-U"
      ;;
    --dask)
      INSTALL_DASK=true
      ;;
    --python3)
      PYTHON3=true
      ;;
    --spark-opts)
      shift
      USER_SPARK_OPTS=$1
      ;;
    --spark-version)
      shift
      APACHE_SPARK_VERSION=$1
      ;;
    --s3fs)
      #NOTEBOOK_DIR_S3_S3NB=false
      NOTEBOOK_DIR_S3_S3CONTENTS=false
      ;;
    --use-sse)
      USE_SSE=true
      ;;
    --kms-id)
      shift
      KMS_ID=$1
      ;;
    #--s3nb) # this stopped working after Jupyter update in early 2017
    #  NOTEBOOK_DIR_S3_S3NB=true
    #  ;;
    -*)
      # do not exit out, just note failure
      error_msg "unrecognized option: $1"
      ;;
    *)
      break;
      ;;
    esac
    shift
done

sudo bash -c 'echo "fs.file-max = 25129162" >> /etc/sysctl.conf'
sudo sysctl -p /etc/sysctl.conf
sudo bash -c 'echo "* soft    nofile          1048576" >> /etc/security/limits.conf'
sudo bash -c 'echo "* hard    nofile          1048576" >> /etc/security/limits.conf'
sudo bash -c 'echo "session    required   pam_limits.so" >> /etc/pam.d/su'

sudo puppet module install spantree-upstart

RELEASE=$(cat /etc/system-release)
REL_NUM=$(ruby -e "puts '$RELEASE'.split.last")

export MAKE="make -j $NPROC"

cd /mnt

#if [ -f /usr/bin/python3.6 ]; then
#  sudo ln -sf /usr/bin/python3.6 /usr/bin/python3
#  sudo ln -sf /usr/bin/pip-3.6 /usr/bin/pip3
#fi

#if [ -f /usr/bin/pip-2.7 ]; then
#  sudo ln -sf /usr/bin/python2.7 /usr/bin/python
#  sudo ln -sf /usr/bin/pip-2.7 /usr/bin/pip
#fi

export NODE_PATH='/usr/lib/node_modules'

sudo ln -sf /usr/local/bin/ipython /usr/bin/
sudo ln -sf /usr/local/bin/jupyter /usr/bin/

sudo python3 -m pip install $PYTHON_PACKAGES || true
sudo python -m pip install $PYTHON_PACKAGES || true

if [ "$SPARKMAGIC" = false ]; then
  sudo rm -f /usr/local/share/jupyter/kernels/sparkmagic-spark
else
  sudo sed -i "s/\"display_name\":\"PySpark\"/\"display_name\":\"SparkMagic PySpark\"/" /usr/local/share/jupyter/kernels/sparkmagic-pyspark/kernel.json || true
  sudo sed -i "s/\"display_name\":\"PySpark3\"/\"display_name\":\"SparkMagic PySpark3\"/" /usr/local/share/jupyter/kernels/sparkmagic-pyspark3/kernel.json || true
fi


if [ "$INSTALL_DASK" = true ]; then
  export PATH=$PATH:/usr/local/bin
  if [ "$IS_MASTER" = true ]; then
    dask-scheduler > /var/log/dask-scheduler.log 2>&1 &
  else
    MASTER_KV=$(grep masterHost /emr/instance-controller/lib/info/job-flow-state.txt)
    MASTER_HOST=$(ruby -e "puts '$MASTER_KV'.gsub('\"','').split.last")
    dask-worker $MASTER_HOST:8786 > /var/log/dask-worker.log 2>&1 &
  fi
fi

#echo ". /mnt/ipython-env/bin/activate" >> ~/.bashrc

# only run below on master instance
if [ "$IS_MASTER" = true ]; then
  
if [ "$JUPYTER_LAB" = true ]; then
  sudo jupyter serverextension enable --py jupyterlab --sys-prefix
fi

if [ "$BIGDL" = true ]; then
  sudo chmod a+rx /home/ec2-user
  export BIGDL_HOME=/home/ec2-user/BigDL
  export BIGDL_VER="0.6.0-SNAPSHOT"
  mkdir /tmp/bigdl_summaries
  /usr/local/bin/tensorboard --debug INFO --logdir /tmp/bigdl_summaries/ > /tmp/tensorboard_bigdl.log 2>&1 &
fi

#sudo python3 -m pip install tornado==4.5.3 -U || true
#sudo python -m pip install tornado==4.5.3 -U || true
sudo python3 -m bash_kernel.install
sudo python -m bash_kernel.install


if [ "$RUBY_KERNEL" = true ]; then
  sudo iruby register
  sudo cp -pr /root/.ipython/kernels/ruby /usr/local/share/jupyter/kernels/
  iruby register
fi

sudo mkdir -p /var/log/jupyter
mkdir -p ~/.jupyter
touch ls ~/.jupyter/jupyter_notebook_config.py

sed -i '/c.NotebookApp.open_browser/d' ~/.jupyter/jupyter_notebook_config.py
echo "c.NotebookApp.open_browser = False" >> ~/.jupyter/jupyter_notebook_config.py

if [ ! "$JUPYTER_LOCALHOST_ONLY" = true ]; then
sed -i '/c.NotebookApp.ip/d' ~/.jupyter/jupyter_notebook_config.py
echo "c.NotebookApp.ip='*'" >> ~/.jupyter/jupyter_notebook_config.py
fi

sed -i '/c.NotebookApp.port/d' ~/.jupyter/jupyter_notebook_config.py
echo "c.NotebookApp.port = $JUPYTER_PORT" >> ~/.jupyter/jupyter_notebook_config.py

if [ ! "$JUPYTER_PASSWORD" = "" ]; then
  sed -i '/c.NotebookApp.password/d' ~/.jupyter/jupyter_notebook_config.py
  HASHED_PASSWORD=$(python3 -c "from notebook.auth import passwd; print(passwd('$JUPYTER_PASSWORD'))")
  echo "c.NotebookApp.password = u'$HASHED_PASSWORD'" >> ~/.jupyter/jupyter_notebook_config.py
else
  sed -i '/c.NotebookApp.token/d' ~/.jupyter/jupyter_notebook_config.py
  echo "c.NotebookApp.token = u''" >> ~/.jupyter/jupyter_notebook_config.py
fi

echo "c.Authenticator.admin_users = {'$JUPYTER_HUB_DEFAULT_USER'}" >> ~/.jupyter/jupyter_notebook_config.py
echo "c.LocalAuthenticator.create_system_users = True" >> ~/.jupyter/jupyter_notebook_config.py
echo "c.ConfigurableHTTPProxy.api_url = 'http://127.0.0.1:$JUPYTER_HUB_API_PORT'" >> ~/.jupyter/jupyter_notebook_config.py
echo "c.JupyterHub.hub_port = 18081" >> ~/.jupyter/jupyter_notebook_config.py

if [ "$SSL" = true ]; then
  #NOTE - replace server.cert and server.key with your own cert and key files
  CERT=/usr/local/etc/server.cert
  KEY=/usr/local/etc/server.key
  sudo openssl req -x509 -nodes -days 3650 -newkey rsa:1024 -keyout $KEY -out $CERT -subj "/C=US/ST=Washington/L=Seattle/O=JupyterCert/CN=JupyterCert"
  
  # the following works for Jupyter but will fail JupyterHub, use options for both instead
  #echo "c.NotebookApp.certfile = u'/usr/local/etc/server.cert'" >> ~/.jupyter/jupyter_notebook_config.py
  #echo "c.NotebookApp.keyfile = u'/usr/local/etc/server.key'" >> ~/.jupyter/jupyter_notebook_config.py

  SSL_OPTS_JUPYTER="--keyfile=/usr/local/etc/server.key --certfile=/usr/local/etc/server.cert"
  SSL_OPTS_JUPYTERHUB="--ssl-key=/usr/local/etc/server.key --ssl-cert=/usr/local/etc/server.cert"
fi

# Javascript/CoffeeScript kernels
if [ "$JS_KERNEL" = true ]; then
  #sudo npm install -g --unsafe-perm ijavascript d3 lodash plotly jp-coffeescript
  sudo ijs --ijs-install=global
  sudo jp-coffee --jp-install=global
fi

if [ "$JULIA_KERNEL" = true ]; then
  sudo chmod a+rwx -R /usr/share/julia/site/
else
  sudo rm -rf /usr/local/share/jupyter/kernels/julia-0.6
fi

# iTorch depends on Torch which is installed with --ml-packages
if [ "$TORCH_KERNEL" = true ]; then
  set +e # workaround for the lengthy torch install-deps, esp when other background process are also running yum
  cd /mnt
  if [ ! "$USE_CACHED_DEPS" = true ]; then
    git clone https://github.com/torch/distro.git torch-distro
  fi
  cd torch-distro
  git pull
  ./install-deps
  ./install.sh -b
  export PATH=$PATH:/mnt/torch-distro/install/bin
  source ~/.profile
  luarocks install lzmq
  luarocks install gnuplot
  cd /mnt
  if [ ! "$USE_CACHED_DEPS" = true ]; then
    git clone https://github.com/facebook/iTorch.git
  fi
  cd iTorch
  sudo env "PATH=$PATH:/usr/local/bin" luarocks make
  sudo chown -R $USER $(dirname $(ipython locate profile))
  sudo cp -pr ~/.ipython/kernels/itorch /usr/local/share/jupyter/kernels/
  set -e
fi

if [ "$R_KERNEL" = true ] || [ "$TOREE_KERNEL" = true ]; then
  aws s3 cp s3://aws-bigdata-blog/artifacts/aws-blog-emr-jupyter/rpy2-2.8.6.tar.gz /mnt/
  sudo python -m pip install /mnt/rpy2-2.8.6.tar.gz

  if [ ! -f /tmp/Renvextra ]; then # check if the rstudio ba was run, it does this already 
   sudo sed -i "s/make/make -j $NPROC/g" /usr/lib64/R/etc/Renviron
  fi
fi

# IRKernal setup 
if [ "$R_KERNEL" = true ]; then
  sudo R --no-save << R_SCRIPT
    devtools::install_github("IRkernel/IRkernel")
    IRkernel::installspec(user = FALSE)
R_SCRIPT
fi

if [ ! "$NOTEBOOK_DIR" = "" ]; then
  NOTEBOOK_DIR="${NOTEBOOK_DIR%/}/" # remove trailing / if exists then add /
  if [[ "$NOTEBOOK_DIR" == s3://* ]]; then
    NOTEBOOK_DIR_S3=true
    # the s3nb does not fully working yet(upload and createe folder not working)
    # s3nb does not work anymore due to Jupyter update
    if [ "$NOTEBOOK_DIR_S3_S3NB" = true ]; then
      cd /mnt
      if [ ! "$USE_CACHED_DEPS" = true ]; then
        git clone https://github.com/tomz/s3nb.git
      fi
      cd s3nb
      sudo python -m pip install entrypoints
      sudo python setup.py install
      if [ "$JUPYTER_HUB" = true ]; then
        sudo python3 -m pip install entrypoints
        sudo python3 setup.py install
      fi

      echo "c.NotebookApp.contents_manager_class = 's3nb.S3ContentsManager'" >> ~/.jupyter/jupyter_notebook_config.py
      echo "c.S3ContentsManager.checkpoints_kwargs = {'root_dir': '~/.checkpoints'}" >> ~/.jupyter/jupyter_notebook_config.py
      # if just bucket with no subfolder, a trailing / is required, otherwise s3nb will break
      echo "c.S3ContentsManager.s3_base_uri = '$NOTEBOOK_DIR'" >> ~/.jupyter/jupyter_notebook_config.py
      #echo "c.S3ContentsManager.s3_base_uri = '${NOTEBOOK_DIR_S3%/}/%U'" >> ~/.jupyter/jupyter_notebook_config.py
      #echo "c.Spawner.default_url = '${NOTEBOOK_DIR_S3%/}/%U'" >> ~/.jupyter/jupyter_notebook_config.py
      #echo "c.Spawner.notebook_dir = '/%U'" >> ~/.jupyter/jupyter_notebook_config.py 
    elif [ "$NOTEBOOK_DIR_S3_S3CONTENTS" = true ]; then
      BUCKET=$(ruby -e "puts '$NOTEBOOK_DIR'.split('//')[1].split('/')[0]")
      FOLDER=$(ruby -e "puts '$NOTEBOOK_DIR'.split('//')[1].split('/')[1..-1].join('/')")
      #sudo python -m pip install s3contents
      cd /mnt
      #aws s3 cp s3://aws-bigdata-blog/artifacts/aws-blog-emr-jupyter/s3contents.zip .
      #unzip s3contents.zip
      
      #git clone https://github.com/tomz/s3contents.git
      #git clone https://github.com/danielfrg/s3contents.git
      #cd s3contents
      #sudo python setup.py install
      echo "c.NotebookApp.contents_manager_class = 's3contents.S3ContentsManager'" >> ~/.jupyter/jupyter_notebook_config.py
      echo "c.S3ContentsManager.bucket = '$BUCKET'" >> ~/.jupyter/jupyter_notebook_config.py
      echo "c.S3ContentsManager.prefix = '$FOLDER'" >> ~/.jupyter/jupyter_notebook_config.py
      # this following is no longer needed, default was fixed in the latest on github
      #echo "c.S3ContentsManager.endpoint_url = 'https://s3.amazonaws.com'" >> ~/.jupyter/jupyter_notebook_config.py
    else
      BUCKET=$(ruby -e "puts '$NOTEBOOK_DIR'.split('//')[1].split('/')[0]")
      FOLDER=$(ruby -e "puts '$NOTEBOOK_DIR'.split('//')[1].split('/')[1..-1].join('/')")
      
      sudo su -c 'echo user_allow_other >> /etc/fuse.conf'
      mkdir -p /mnt/s3fs-cache
      mkdir -p /mnt/$BUCKET
      #/usr/local/bin/s3fs -o allow_other -o iam_role=auto -o umask=0 $BUCKET /mnt/$BUCKET
      # -o nodnscache -o nosscache -o parallel_count=20  -o multipart_size=50
      S3SSE_FLAG=""
      if [ "$USE_SSE" = true ]; then
        if [ ! "KMS_ID" = "" ]; then
          S3SSE_FLAG = "-o use_sse='kmsid:$KMS_ID'"
        else
          S3SSE_FLAG = "-o use_sse"
        fi
      fi
      /usr/local/bin/s3fs -o allow_other -o iam_role=auto -o umask=0 -o url=https://s3.amazonaws.com  -o no_check_certificate -o enable_noobj_cache -o use_cache=/mnt/s3fs-cache $S3SSE_FLAG $BUCKET /mnt/$BUCKET
      if [ "$JUPYTER_HUB" = true ]; then
        mkdir -p /mnt/$BUCKET/$FOLDER/${JUPYTER_HUB_DEFAULT_USER}
      fi
      #/usr/local/bin/s3fs -o allow_other -o iam_role=auto -o umask=0 -o use_cache=/mnt/s3fs-cache $BUCKET /mnt/$BUCKET
      echo "c.NotebookApp.notebook_dir = '/mnt/$BUCKET/$FOLDER'" >> ~/.jupyter/jupyter_notebook_config.py
      echo "c.ContentsManager.checkpoints_kwargs = {'root_dir': '.checkpoints'}" >> ~/.jupyter/jupyter_notebook_config.py
      if [ "$JUPYTER_HUB" = true ]; then
        echo "try:" >> ~/.jupyter/jupyter_notebook_config.py
        echo "  from jupyterhub.spawner import LocalProcessSpawner" >> ~/.jupyter/jupyter_notebook_config.py
        echo "  class MySpawner(LocalProcessSpawner):" >> ~/.jupyter/jupyter_notebook_config.py
        echo "      def _notebook_dir_default(self):" >> ~/.jupyter/jupyter_notebook_config.py
        echo "        return c.NotebookApp.notebook_dir + '/' + self.user.name" >> ~/.jupyter/jupyter_notebook_config.py
        echo "  c.JupyterHub.spawner_class = MySpawner" >> ~/.jupyter/jupyter_notebook_config.py 
        echo "except:" >> ~/.jupyter/jupyter_notebook_config.py
        echo "  print('jupyterhub module not found')" >> ~/.jupyter/jupyter_notebook_config.py
      fi
    fi
  else
    echo "c.NotebookApp.notebook_dir = '$NOTEBOOK_DIR'" >> ~/.jupyter/jupyter_notebook_config.py
    echo "c.ContentsManager.checkpoints_kwargs = {'root_dir': '.checkpoints'}" >> ~/.jupyter/jupyter_notebook_config.py
  fi
fi

if [ ! "$JUPYTER_HUB_DEFAULT_USER" = "" ]; then
  sudo adduser $JUPYTER_HUB_DEFAULT_USER
fi

if [ "$COPY_SAMPLES" = true ]; then
  cd ~
  if [ "$NOTEBOOK_DIR_S3" = true ]; then
    aws s3 sync s3://aws-bigdata-blog/artifacts/aws-blog-emr-jupyter/notebooks/ ${NOTEBOOK_DIR}samples/ || true
    if [ "$JUPYTER_HUB" = true ]; then
      aws s3 sync s3://aws-bigdata-blog/artifacts/aws-blog-emr-jupyter/notebooks/ ${NOTEBOOK_DIR}${JUPYTER_HUB_DEFAULT_USER}/samples/ || true
    fi
  else
    if [ ! "$NOTEBOOK_DIR" = "" ]; then
      mkdir -p ${NOTEBOOK_DIR}samples || true
      sudo mkdir /home/$JUPYTER_HUB_DEFAULT_USER/${NOTEBOOK_DIR}samples || true
    fi
    aws s3 sync s3://aws-bigdata-blog/artifacts/aws-blog-emr-jupyter/notebooks/ ${NOTEBOOK_DIR}samples || true
    sudo cp -pr ${NOTEBOOK_DIR}samples /home/$JUPYTER_HUB_DEFAULT_USER/
    sudo chown -R $JUPYTER_HUB_DEFAULT_USER:$JUPYTER_HUB_DEFAULT_USER /home/$JUPYTER_HUB_DEFAULT_USER/${NOTEBOOK_DIR}samples
  fi
fi


wait_for_spark() {
  while [ ! -f /var/run/spark/spark-history-server.pid ]
  do
    sleep 5
  done
}

setup_jupyter_process_with_bigdl() {
  wait_for_spark
  sudo chmod a+rx /home/ec2-user
  sudo chmod a+rwx -R /home/ec2-user/BigDL
  export PYTHON_API_PATH=${BIGDL_HOME}/dist/lib/bigdl-$BIGDL_VER-python-api.zip
  export BIGDL_JAR_PATH=${BIGDL_HOME}/dist/lib/bigdl-$BIGDL_VER-jar-with-dependencies.jar
  cat ${BIGDL_HOME}/dist/conf/spark-bigdl.conf | sudo tee -a /etc/spark/conf/spark-defaults.conf
  sudo puppet apply << PUPPET_SCRIPT
  include 'upstart'
  upstart::job { 'jupyter':
    description    => 'Jupyter',
    respawn        => true,
    respawn_limit  => '0 10',
    start_on       => 'runlevel [2345]',
    stop_on        => 'runlevel [016]',
    console        => 'output',
    chdir          => '/home/hadoop',
    script           => '
    sudo su - hadoop > /var/log/jupyter/jupyter.log 2>&1 <<BASH_SCRIPT
    export NODE_PATH="$NODE_PATH"
    export PYSPARK_DRIVER_PYTHON="jupyter"
    export PYSPARK_DRIVER_PYTHON_OPTS="$NOTEBOOK_OR_LAB --no-browser $SSL_OPTS_JUPYTER --log-level=INFO"
    export NOTEBOOK_DIR="$NOTEBOOK_DIR"

    export BIGDL_HOME=/home/ec2-usr/BigDL
    export SPARK_HOME=/usr/lib/spark
    export YARN_CONF_DIR=/etc/hadoop/conf
    export PYTHONPATH=${PYTHON_API_PATH}:$PYTHONPATH
    source ${BIGDL_HOME}/dist/bin/bigdl.sh
    #pyspark --py-files ${PYTHON_API_PATH} --jars ${BIGDL_JAR_PATH} --conf spark.driver.extraClassPath=${BIGDL_JAR_PATH} --conf spark.executor.extraClassPath=bigdl-${BIGDL_VER}-jar-with-dependencies.jar
    pyspark --py-files ${PYTHON_API_PATH} --jars ${BIGDL_JAR_PATH}
BASH_SCRIPT
    ',
  }
PUPPET_SCRIPT
}

background_install_proc() {
  wait_for_spark

  # do this here so that it does not break puppet which needs python 2
  if [ "$PYTHON3" = true ]; then
    sudo update-alternatives --set python /usr/bin/python3.6
  fi
  
  if ! grep "spark.sql.catalogImplementation" /etc/spark/conf/spark-defaults.conf; then
    sudo bash -c "echo 'spark.sql.catalogImplementation  hive' >> /etc/spark/conf/spark-defaults.conf"
  fi
  
  if [ "$GRAPHFRAMES" = true ]; then
    cd /mnt
    export GRAPHFRAMES_HOME="/home/ec2-user/graphframes"
    export GRAPHFRAMES_VER="0.6.0-SNAPSHOT"
    export GRAPHFRAMES_SPARK_VER="2.3"
    sudo chmod a+rx /home/ec2-user
    sudo chmod a+rwx -R /home/ec2-user/graphframes
    #/home/ec2-user/graphframes/target/scala-2.11/graphframes-assembly-0.6.0-SNAPSHOT-spark2.3.jar
    jar xvf $GRAPHFRAMES_HOME/target/scala-2.11/graphframes-assembly-$GRAPHFRAMES_VER-spark$GRAPHFRAMES_SPARK_VER.jar graphframes
    # install the unpacked python graphframes package into Python2 and Python3
    sudo cp -pr graphframes $(python27 -c "import site; print(site.getsitepackages()[0])")
    sudo cp -pr graphframes $(python3 -c "import site; print(site.getsitepackages()[0])")
    rm -rf graphframes
    # TODO - below may create multuple spark.jars entries, the last one could overwrite the previous. Do merge instead later
    sudo bash -c "echo 'spark.jars                       $GRAPHFRAMES_HOME/target/scala-2.11/graphframes-assembly-$GRAPHFRAMES_VER-spark$GRAPHFRAMES_SPARK_VER.jar' >> /etc/spark/conf/spark-defaults.conf"
    
  fi

  
  if [ ! -f /tmp/Renvextra ]; then # check if the rstudio BA maybe already done this
    cat << 'EOF' > /tmp/Renvextra
JAVA_HOME="/etc/alternatives/jre"
HADOOP_HOME_WARN_SUPPRESS="true"
HADOOP_HOME="/usr/lib/hadoop"
HADOOP_PREFIX="/usr/lib/hadoop"
HADOOP_MAPRED_HOME="/usr/lib/hadoop-mapreduce"
HADOOP_YARN_HOME="/usr/lib/hadoop-yarn"
HADOOP_COMMON_HOME="/usr/lib/hadoop"
HADOOP_HDFS_HOME="/usr/lib/hadoop-hdfs"
HADOOP_CONF_DIR="/usr/lib/hadoop/etc/hadoop"
YARN_CONF_DIR="/usr/lib/hadoop/etc/hadoop"
YARN_HOME="/usr/lib/hadoop-yarn"
HIVE_HOME="/usr/lib/hive"
HIVE_CONF_DIR="/usr/lib/hive/conf"
HBASE_HOME="/usr/lib/hbase"
HBASE_CONF_DIR="/usr/lib/hbase/conf"
SPARK_HOME="/usr/lib/spark"
SPARK_CONF_DIR="/usr/lib/spark/conf"
PATH=${PWD}:${PATH}
EOF

  #if [ "$PYSPARK_PYTHON" = "python3" ]; then
  if [ "$PYTHON3" = true ]; then
    cat << 'EOF' >> /tmp/Renvextra
PYSPARK_PYTHON="python3"
EOF
  fi

  cat /tmp/Renvextra | sudo tee -a /usr/lib64/R/etc/Renviron

  sudo mkdir -p /mnt/spark
  sudo chmod a+rwx /mnt/spark
  if [ -d /mnt1 ]; then
    sudo mkdir -p /mnt1/spark
    sudo chmod a+rwx /mnt1/spark
  fi

#  sudo R --no-save << R_SCRIPT
#  library(devtools)
#  devtools::install_github("rstudio/sparklyr")
#  install.packages(c('nycflights13', 'Lahman', 'data.table'), repos="$R_REPOS", quiet = TRUE)
#R_SCRIPT

  set +e # workaround for if SparkR is already installed by other BA
  # install SparkR and SparklyR for R - toree ifself does not need this
  sudo R --no-save << R_SCRIPT
  library(devtools)
  install('/usr/lib/spark/R/lib/SparkR')
R_SCRIPT
  set -e

  fi # end if -f /tmp/Renvextra

  sudo python3 -m pip install /home/ec2-user/incubator-toree/dist/toree-pip || true
  sudo python -m pip install /home/ec2-user/incubator-toree/dist/toree-pip || true
  #sudo ln -sf /usr/local/bin/jupyter-toree /usr/bin/
  export SPARK_HOME="/usr/lib/spark"
  SPARK_PACKAGES=""

  if [ "$PYTHON3" = true ]; then
    PYSPARK_PYTHON="python3"
  else
    PYSPARK_PYTHON="python"
  fi
  
  if [ ! "$USER_SPARK_OPTS" = "" ]; then
    SPARK_OPTS=$USER_SPARK_OPTS
    SPARK_PACKAGES=$(ruby -e "opts='$SPARK_OPTS'.split;pkgs=nil;opts.each_with_index{|o,i| pkgs=opts[i+1] if o.start_with?('--packages')};puts pkgs || '$SPARK_PACKAGES'")
    export SPARK_OPTS
    export SPARK_PACKAGES
    
    sudo jupyter toree install --interpreters=$INTERPRETERS --spark_home=$SPARK_HOME --python_exec=$PYSPARK_PYTHON --spark_opts="$SPARK_OPTS"
    # NOTE - toree does not pick SPARK_OPTS, so use the following workaround until it's fixed  
    if [ ! "$SPARK_PACKAGES" = "" ]; then
      if ! grep "spark.jars.packages" /etc/spark/conf/spark-defaults.conf; then
        sudo bash -c "echo 'spark.jars.packages              $SPARK_PACKAGES' >> /etc/spark/conf/spark-defaults.conf"
      fi
    fi
  else
    sudo jupyter toree install --interpreters=$INTERPRETERS --spark_home=$SPARK_HOME --python_exec=$PYSPARK_PYTHON
  fi

  
  if [ "$PYTHON3" = true ]; then
    sudo bash -c 'echo "" >> /etc/spark/conf/spark-env.sh'
    sudo bash -c 'echo "export PYSPARK_PYTHON=/usr/bin/python3" >> /etc/spark/conf/spark-env.sh'
    
    #if [ -f /usr/local/share/jupyter/kernels/apache_toree_pyspark/kernel.json ]; then
    #  sudo bash -c 'sed -i "s/\"PYTHON_EXEC\": \"python\"/\"PYTHON_EXEC\": \"\/usr\/bin\/python3\"/g" /usr/local/share/jupyter/kernels/apache_toree_pyspark/kernel.json'
    #fi
    
  fi
  
  # the following dirs could cause conflict, so remove them
  rm -rf ~/.m2/
  rm -rf ~/.ivy2/
  
  if [ "$NO_JUPYTER" = false ]; then
    echo "Starting Jupyter notebook via pyspark"
    cd ~
    #PYSPARK_DRIVER_PYTHON=jupyter PYSPARK_DRIVER_PYTHON_OPTS="notebook --no-browser" pyspark > /var/log/jupyter/jupyter.log &
    if [ "$BIGDL" = false ]; then
      sudo puppet apply << PUPPET_SCRIPT
      include 'upstart'
      upstart::job { 'jupyter':
        description    => 'Jupyter',
        respawn        => true,
        respawn_limit  => '0 10',
        start_on       => 'runlevel [2345]',
        stop_on        => 'runlevel [016]',
        console        => 'output',
        chdir          => '/home/hadoop',
        script           => '
        sudo su - hadoop > /var/log/jupyter/jupyter.log 2>&1 <<BASH_SCRIPT
        export NODE_PATH="$NODE_PATH"
        export SPARK_HOME=/usr/lib/spark
        export YARN_CONF_DIR=/etc/hadoop/conf
        export PYSPARK_DRIVER_PYTHON="jupyter"
        export PYSPARK_DRIVER_PYTHON_OPTS="$NOTEBOOK_OR_LAB --no-browser $SSL_OPTS_JUPYTER --log-level=INFO"
        export NOTEBOOK_DIR="$NOTEBOOK_DIR"
        pyspark
BASH_SCRIPT
        ',
      }
PUPPET_SCRIPT
    else
      setup_jupyter_process_with_bigdl
    fi
  fi

}

create_hdfs_user() {
  wait_for_spark
  sudo -u hdfs hdfs dfs -mkdir /user/$JUPYTER_HUB_DEFAULT_USER
  sudo -u hdfs hdfs dfs -chown $JUPYTER_HUB_DEFAULT_USER:$JUPYTER_HUB_DEFAULT_USER /user/$JUPYTER_HUB_DEFAULT_USER
  sudo -u hdfs hdfs dfs -chmod -R 777 /user/$JUPYTER_HUB_DEFAULT_USER
}

# apache toree install
if [ "$TOREE_KERNEL" = true ]; then
  echo "Running background process to install Apacke Toree"

  cd /mnt

  if [ "$RUN_AS_STEP" = true ]; then
    background_install_proc
  else
    background_install_proc &
  fi
else
  if [ "$NO_JUPYTER" = false ]; then
    echo "Starting Jupyter notebook"
    if [ "$BIGDL" = false ]; then
      sudo puppet apply << PUPPET_SCRIPT
      include 'upstart'
      upstart::job { 'jupyter':
          description    => 'Jupyter',
          respawn        => true,
          respawn_limit  => '0 10',
          start_on       => 'runlevel [2345]',
          stop_on        => 'runlevel [016]',
          console        => 'output',
          chdir          => '/home/hadoop',
          env            => {'NOTEBOOK_DIR' => '$NOTEBOOK_DIR', 'NODE_PATH' => '$NODE_PATH', 'SPARK_HOME' => '/usr/lib/spark', 'YARN_CONF_DIR' => '/etc/hadoop/conf'},
          exec           => 'sudo su - hadoop -c "jupyter $NOTEBOOK_OR_LAB --no-browser $SSL_OPTS_JUPYTER" > /var/log/jupyter/jupyter.log 2>&1',
      }
PUPPET_SCRIPT
    else
      setup_jupyter_process_with_bigdl &
    fi
  fi
fi

if [ "$JUPYTER_HUB" = true ]; then

  if [ ! "$JUPYTER_HUB_DEFAULT_USER" = "" ]; then
    create_hdfs_user &
  fi
  # change the password of the hadoop user to JUPYTER_PASSWORD
  if [ ! "$JUPYTER_PASSWORD" = "" ]; then
    sudo sh -c "echo '$JUPYTER_PASSWORD' | passwd --stdin $JUPYTER_HUB_DEFAULT_USER"
  fi
  
  sudo ln -sf /usr/local/bin/jupyterhub /usr/bin/
  sudo ln -sf /usr/local/bin/jupyterhub-singleuser /usr/bin/
  mkdir -p /mnt/jupyterhub
  cd /mnt/jupyterhub
  
  echo "Starting Jupyterhub"
  #sudo jupyterhub $SSL_OPTS_JUPYTERHUB --port=$JUPYTER_HUB_PORT --ip=$JUPYTER_HUB_IP --log-file=/var/log/jupyter/jupyterhub.log --config ~/.jupyter/jupyter_notebook_config.py &
  sudo puppet apply << PUPPET_SCRIPT
  include 'upstart'
  upstart::job { 'jupyterhub':
      description    => 'JupyterHub',
      respawn        => true,
      respawn_limit  => '0 10',
      start_on       => 'runlevel [2345]',
      stop_on        => 'runlevel [016]',
      console        => 'output',
      chdir          => '/mnt/jupyterhub',
      env            => {'NOTEBOOK_DIR' => '$NOTEBOOK_DIR', 'NODE_PATH' => '$NODE_PATH', 'SPARK_HOME' => '/usr/lib/spark', 'YARN_CONF_DIR' => '/etc/hadoop/conf'},
      exec           => 'sudo /usr/bin/jupyterhub --pid-file=/var/run/jupyter.pid $SSL_OPTS_JUPYTERHUB --port=$JUPYTER_HUB_PORT --ip=$JUPYTER_HUB_IP --log-file=/var/log/jupyter/jupyterhub.log --config /home/hadoop/.jupyter/jupyter_notebook_config.py'
  }
PUPPET_SCRIPT

fi

cat << 'EOF' > /tmp/jupyter_logpusher.config
{
  "/var/log/jupyter/" : {
    "includes" : [ "(.*)" ],
    "s3Path" : "node/$instance-id/applications/jupyter/$0",
    "retentionPeriod" : "5d",
    "logType" : [ "USER_LOG", "SYSTEM_LOG" ]
  }
}
EOF
cat /tmp/jupyter_logpusher.config | sudo tee -a /etc/logpusher/jupyter.config

fi # endif master true
echo "Bootstrap action finished"
