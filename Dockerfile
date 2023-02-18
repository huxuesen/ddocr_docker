# 基础镜像
FROM alpine:edge

# 维护者信息
LABEL maintainer "hxs"
LABEL org.opencontainers.image.source=https://github.com/huxuesen/ocr-docker

# Envirenment for onnxruntime & dddocr
ENV ONNXRUNTIME_TAG=v1.13.1
ENV DDDDOCR_VERSION=master

# 换源 & Install packages
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories && \
    echo 'http://mirrors.ustc.edu.cn/alpine/v3.16/main' >> /etc/apk/repositories && \
    echo 'http://mirrors.ustc.edu.cn/alpine/v3.16/community' >> /etc/apk/repositories && \
    apk update && \
    apk add --update --no-cache bash git tzdata ca-certificates file python3 py3-six && \
    # ln -s /usr/bin/python3 /usr/bin/python && \
    [[ $(getconf LONG_BIT) = "32" ]] && \
    { bashtmp='' && cxxtmp=''; } || { \
    [[ -z $(file /bin/busybox | grep -i "arm") ]] && \
    { bashtmp='/onnxruntime/build.sh' && cxxtmp=''; } || \
    { bashtmp='setarch arm64 /onnxruntime/build.sh' && cxxtmp='-Wno-psabi'; }; } && \
    echo $bashtmp && echo $cxxtmp && {\
    [[ -n "$bashtmp" ]] && { \
    apk add --update --no-cache py3-opencv py3-pillow && { \
    apk add --update --no-cache --virtual .build_deps nano openssh-client \
    cmake make perl autoconf g++=11.2.1_git20220219-r2 libexecinfo-dev=1.1-r1 \
    automake linux-headers libtool util-linux openblas-dev python3-dev protobuf-dev \
    date-dev gtest-dev eigen-dev flatbuffers-dev=2.0.0-r1 patch boost-dev nlohmann-json \
    py3-pybind11-dev py3-pip py3-setuptools py3-wheel py3-numpy-dev || \
    apk add --update --no-cache --virtual .build_deps nano openssh-client \
    cmake make perl autoconf g++=11.2.1_git20220219-r2 libexecinfo-dev=1.1-r1 \
    automake linux-headers libtool util-linux openblas-dev python3-dev protobuf-dev \
    date-dev gtest-dev eigen-dev patch boost-dev nlohmann-json \
    py3-pybind11-dev py3-pip py3-setuptools py3-wheel py3-numpy-dev ;} && \
    git clone --depth 1 --branch $ONNXRUNTIME_TAG https://github.com/Microsoft/onnxruntime && \
    cd /onnxruntime && \
    git submodule update --init --recursive && \
    cd .. && \
    $bashtmp --config MinSizeRel  \
    --parallel \
    --build_wheel \
    --enable_pybind \
    --cmake_extra_defines \
    CMAKE_CXX_FLAGS="-Wno-deprecated-copy -Wno-unused-variable -Wno-unused-parameter $cxxtmp"\
    onnxruntime_BUILD_UNIT_TESTS=OFF \
    onnxruntime_BUILD_SHARED_LIB=OFF \
    onnxruntime_USE_PREINSTALLED_EIGEN=ON \
    onnxruntime_PREFER_SYSTEM_LIB=ON \
    eigen_SOURCE_PATH=/usr/include/eigen3 \
    --skip_tests && \
    apk add --update --no-cache libprotobuf-lite && \
    pip install --no-cache-dir /onnxruntime/build/Linux/MinSizeRel/dist/onnxruntime*.whl && \
    ln -s $(python -c 'import warnings;warnings.filterwarnings("ignore");\
    from distutils.sysconfig import get_python_lib;print(get_python_lib())')/onnxruntime/capi/libonnxruntime_providers_shared.so /usr/lib && \
    cd / && rm -rf /onnxruntime && \
    git clone --branch $DDDDOCR_VERSION https://github.com/huxuesen/ddocr.git && \
    cd ddddocr && \
    sed -i '/install_package_data/d' setup.py && \
    sed -i '/install_requires/d' setup.py && \
    python setup.py install && \
    cd / && rm -rf /ddddocr && \
    apk del .build_deps ;} || { \
    apk add --update --no-cache libprotobuf-lite && \
    echo "Onnxruntime Builder does not currently support building i386 and arm32 wheels";} ;} && \
    rm -rf /var/cache/apk/* && \
    rm -rf /usr/share/man/* 
