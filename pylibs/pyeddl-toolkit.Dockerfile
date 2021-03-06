ARG BASE_IMAGE

# base image
FROM ${BASE_IMAGE} as base

# set metadata
LABEL website="https://github.com/deephealthproject/" \
      description="DeepHealth European Distributed Deep Learning Library" \
      software="deephealth-eddl,deephealth-ecvl,deephealth-pyeddl"

ARG eddl_src="/usr/local/src/eddl"

ARG pyeddl_src_origin="pyeddl"
ARG pyeddl_src_target="/usr/local/src/pyeddl"

# Run git submodule update [--init] --recursive first
COPY ${pyeddl_src_origin} ${pyeddl_src_target}

# link the cudart, cublas and curand libraries on "standard" system locations
RUN /bin/bash -c "if [[ \"${BUILD_TARGET}\" == \"GPU\" ]]; then \
        ln -s /usr/local/cuda-10.1/targets/x86_64-linux/lib/libcudart.so /usr/lib/ \
        && ln -s /usr/local/cuda-10.1/targets/x86_64-linux/lib/libcurand.so /usr/lib/ \
        && ln -s /usr/local/cuda-10.1/targets/x86_64-linux/lib/libcublas.so /usr/lib/ \
        && export EDDL_WITH_CUDA=\"true\" ; \
    fi" \
    && cd ${pyeddl_src_target} \
    && echo "\nLinking eddl library..." >&2 \
    && rm -rf third_party/eddl \
    && ln -s ${eddl_src} third_party/ \
    && echo "\nInstalling pyeddl module..." >&2 \
    && python3 setup.py install --record install.log \
    && rm -rf build/temp.*
