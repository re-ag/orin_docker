#
# this dockerfile roughly follows the 'Install ROS From Source' procedures from:
#   https://docs.ros.org/en/humble/Installation/Alternatives/Ubuntu-Development-Setup.html
#
ARG BASE_IMAGE=nvcr.io/nvidia/l4t-base:r35.1.0
FROM ${BASE_IMAGE}

ENV ROS_DISTRO=humble
ENV ROS_ROOT=/opt/ros/${ROS_DISTRO}
ENV ROS_PYTHON_VERSION=3

ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL /bin/bash
SHELL ["/bin/bash", "-c"] 

WORKDIR /tmp

# change the locale from POSIX to UTF-8
RUN locale-gen en_US en_US.UTF-8 && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV PYTHONIOENCODING=utf-8

# set Python3 as default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

# 
# add the ROS deb repo to the apt sources list
#
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
		curl \
		wget \
		gnupg2 \
		lsb-release \
		ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

#
# Install any utils needed for execution
#
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

#
# Install nvidia-cuda-dev for CUDA developer packages
# Use nvidia-cuda if need CUDA runtime only
#
RUN apt-get update && apt-get install -y --no-install-recommends \
    nvidia-cuda-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

#
# Install nvidia-cudnn8-dev for CuDNN developer packages
# Use nvidia-cudnn8 if need CuDNN runtime only
#
RUN apt-get update && apt-get install -y --no-install-recommends \
    nvidia-cudnn8-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

#
# Install nvidia-tensorrt-dev for TensorRT developer packages
# Use nvidia-tensorrt if need TensorRT runtime only
#
RUN apt-get update && apt-get install -y --no-install-recommends \
    nvidia-tensorrt-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean
    
ENV CUDA_HOME="/usr/local/cuda"
ENV PATH="/usr/local/cuda/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"

RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null


# 
# install development packages
#
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
		build-essential \
		cmake \
		git \
		libbullet-dev \
		libpython3-dev \
		python3-colcon-common-extensions \
		python3-flake8 \
		python3-pip \
		python3-numpy \
		python3-pytest-cov \
		python3-rosdep \
		python3-setuptools \
		python3-vcstool \
		python3-rosinstall-generator \
		libasio-dev \
		libtinyxml2-dev \
		libcunit1-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# install some pip packages needed for testing
RUN python3 -m pip install -U \
		argcomplete \
		flake8-blind-except \
		flake8-builtins \
		flake8-class-newline \
		flake8-comprehensions \
		flake8-deprecated \
		flake8-docstrings \
		flake8-import-order \
		flake8-quotes \
		pytest-repeat \
		pytest-rerunfailures \
		pytest

# 
# install OpenCV (with CUDA)
#
#RUN apt-get purge -y *opencv*
#RUN apt-get install --fix-broken -y
#ARG OPENCV_URL=https://nvidia.box.com/shared/static/5v89u6g5rb62fpz4lh0rz531ajo2t5ef.gz
#ARG OPENCV_DEB=OpenCV-4.5.0-aarch64.tar.gz

#COPY ./opencv_install.sh /tmp/opencv_install.sh
#RUN cd /tmp && ./opencv_install.sh ${OPENCV_URL} ${OPENCV_DEB}
    
#
# Install nvidia-opencv-dev for OpenCV developer packages
# Use nvidia-opencv if need OpenCV runtime only
#
RUN apt-get update && apt-get install -y --no-install-recommends \
    nvidia-opencv-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean
    
# 
# upgrade cmake - https://stackoverflow.com/a/56690743
# this is needed to build some of the ROS2 packages
#
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
		  software-properties-common \
		  apt-transport-https \
		  ca-certificates \
		  gnupg \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean
		  	  
RUN wget -qO - https://apt.kitware.com/keys/kitware-archive-latest.asc | apt-key add - && \
    apt-add-repository "deb https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" && \
    apt-get update && \
    apt-get install -y --no-install-recommends --only-upgrade \
            cmake \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean
    
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 42D5A192B819C5DA 

RUN apt-get update && \
	mkdir -p ${ROS_ROOT}/src && \
	cd ${ROS_ROOT} && \
	git clone https://github.com/re-ag/ros2.git -b tcl-humble && \
	vcs import src < ros2/ros2.repos && \
	rm -rf /etc/ros/rosdep/sources.list.d/20-default.list && \
	rosdep init && \
	rosdep update && \
	rosdep install --from-paths src --rosdistro ${ROS_DISTRO} --ignore-src -y --skip-keys "fastcdr rti-connext-dds-6.0.1 urdfdom_headers libopencv-dev libopencv-contrib-dev libopencv-imgproc-dev python-opencv python3-opencv" && \
	rm -rf /var/lib/apt/lists/* && \
	apt-get clean


RUN cd ${ROS_ROOT} && colcon build --symlink-install 

#
# Autoware.universe dependencies
#
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
	libpcl-dev \
	librange-v3-dev \
	geographiclib-tools \
	libgeographic-dev \
	libpcap-dev \
	nlohmann-json3-dev \
	libfmt-dev \
	libpugixml-dev \
	libnl-genl-3-dev \
	libangles-dev \
	libcpprest-dev \
	libtbb-dev \
	libcgal-dev \
	spirv-tools \
	spirv-headers \
	libopenblas-dev \
	libzmq3-dev \
	libspnav-dev \
	libbluetooth-dev \
	libcwiid-dev \
	libgraphicsmagick++1-dev \
	&& rm -rf /var/lib/apt/lists/* \
	&& apt-get clean


RUN TEST_PLUGINLIB_PACKAGE="${ROS_ROOT}/build/pluginlib/pluginlib_enable_plugin_testing/install/test_pluginlib__test_pluginlib/share/test_pluginlib/package.xml" && \
    sed -i '/<\/description>/a <license>BSD<\/license>' $TEST_PLUGINLIB_PACKAGE && \
    sed -i '/<\/description>/a <maintainer email="michael@openrobotics.org">Michael Carroll<\/maintainer>' $TEST_PLUGINLIB_PACKAGE && \
    cat $TEST_PLUGINLIB_PACKAGE

RUN cd ${ROS_ROOT} && colcon build --symlink-install --packages-select pluginlib

RUN cd / &&  git clone https://github.com/autowarefoundation/autoware.git
  
RUN cd /autoware

RUN mkdir -p /autoware/src && \
    cd /autoware && \
    vcs import --input https://raw.githubusercontent.com/autowarefoundation/autoware/main/autoware.repos src && \
    vcs pull src && \
    sudo apt-get update




#echo -e "RMW_IMPLEMENTATION=rmw_cyclonedds_cpp \nif [ ! -e /root/shared_dir/cycloneDDS_configured ]; then \n\t sudo sysctl -w net.core.rmem_max=2147483647\n\t sudo ip link set lo multicast on\n\t touch /root/shared_dir/cycloneDDS_configured\nfi" >> ~/.bashrc	

#RUN pip3 install \
#		bson \
#		flask

#
# remove other versions of Python3
# workaround for 'Could NOT find Python3 (missing: Python3_NumPy_INCLUDE_DIRS Development'
#RUN apt purge -y python3.9 libpython3.9* || echo "python3.9 not found, skipping removal" && \
#ls -ll /usr/bin/python*

#COPY ./ros_entrypoint.sh /ros_entrypoint.sh

#RUN sed -i \
#    's/ros_env_setup="\/opt\/ros\/$ROS_DISTRO\/setup.bash"/ros_env_setup="${ROS_ROOT}\/install\/setup.bash"/g' \
#    /ros_entrypoint.sh && \
#    cat /ros_entrypoint.sh

RUN echo 'source ${ROS_ROOT}/install/setup.bash' >> /root/.bashrc

#ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]
WORKDIR /
