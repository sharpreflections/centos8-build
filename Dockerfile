FROM centos:8 AS base
LABEL maintainer="juergen.wind@sharpreflections.com"

WORKDIR /build/
RUN cd /etc/yum.repos.d/ && sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*  && \
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-* && \
    yum -y update && yum -y upgrade && yum clean all


FROM base AS build-protobuf
RUN yum -y install unzip autoconf automake libtool gcc-c++ make && \
    echo "Downloading protobuf 3.7.0:" && curl --progress-bar https://codeload.github.com/protocolbuffers/protobuf/tar.gz/v3.7.0 --output protobuf-3.7.0.tar.gz && \
    echo "Downloading protobuf 3.19.0:" && curl --progress-bar https://codeload.github.com/protocolbuffers/protobuf/tar.gz/v3.19.0 --output protobuf-3.19.0.tar.gz && \
    for file in *; do echo -n "Extracting $file: " && tar -xf $file && echo "done"; done && \
    cd protobuf-3.7.0 && \
    ./autogen.sh && \
    ./configure --prefix=/opt/protobuf-3.7 && \
    make --jobs=$(nproc --all) && make install && \
    cd .. && \
    cd protobuf-3.19.0 && \
    ./autogen.sh && \
    ./configure --prefix=/opt/protobuf-3.19.0 && \
    make --jobs=$(nproc --all) && make install && \
    cd .. && \
    rm -rf /build/*

FROM base AS build-clazy
RUN yum -y install git make cmake gcc gcc-c++ llvm-devel clang-devel && \
    git clone https://github.com/KDE/clazy.git --branch 1.9 && \
    mkdir clazy-build && cd clazy-build && \
    cmake ../clazy -DUSER_LIBS=-lstdc++fs -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/clazy-1.9 && \
    make --jobs=$(nproc --all) && make install && \
    rm -rf /build/*

FROM base AS production
COPY --from=build-protobuf /opt /opt
COPY --from=build-clazy    /opt /opt
COPY --from=quay.io/sharpreflections/centos7-build-qt /p /p 

# Our build dependencies
RUN yum -y install xorg-x11-server-utils libX11-devel libSM-devel libxml2-devel libGL-devel \
                   libGLU-devel libibverbs-devel freetype-devel which libXtst libXext-devel && \
    # we need some basic fonts and manpath for the mklvars.sh script
    yum -y install urw-fonts man && \
    # Requirements for using epel
    yum -y install yum-utils epel-release.noarch && \
    # clang, gcc and svn
    yum -y install @development gcc-gfortran gcc-toolset-9 gcc-toolset-10 \
                   @llvm-toolset libomp-devel subversion cmake distcc-server clang-tools-extra && \
    # For building OSMesa
    yum -y install python2 && \
    # Misc (developer) tools and xvfb for QTest
    yum -y install strace valgrind bc joe vim nano mc psmisc \
                   xorg-x11-server-Xvfb wget && \
    yum clean all && \
    # install numpy and scipy pip2 and pip3 are already installed
    pip2 install numpy scipy && \
    pip3 install numpy scipy
