ARG BASE_IMAGE
ARG TOOLKIT_IMAGE

# Declare Toolkit image
FROM ${TOOLKIT_IMAGE} AS toolkit

############################
#### INTERMEDIATE Stage ####
############################
FROM ${BASE_IMAGE} AS prepare_install

# set arguments
ARG eddl_src_origin="eddl"
ARG eddl_src_target="/usr/local/src/eddl"

# make a temporary copy of libraries
COPY --from=toolkit /usr/local/etc /tmp/local/etc
COPY --from=toolkit /usr/local/include /tmp/local/include
COPY --from=toolkit /usr/local/lib /tmp/local/lib
COPY --from=toolkit /usr/local/share /tmp/local/share
COPY --from=toolkit /usr/local/src/eddl/build/install_manifest.txt /tmp/local/install_manifest.txt

# merge existing system directories with those containing libraries
RUN cd /tmp/local && sed -e 's+/usr/local/++g' /tmp/local/install_manifest.txt | \
    while IFS= read -r line; do echo ">>> $line" ; rsync --relative "${line}" "/usr/local/" || exit ; done \
    && rm -rf /tmp/*

######################
#### TARGET Stage ####
######################
FROM nvidia-scratch AS libs.eddl

# Set metadata
LABEL website="https://github.com/deephealthproject" \
      description="DeepHealth European Distributed Deep Learning Library" \
      software="deephealth-eddl"

COPY --from=prepare_install / /

# default cmd
CMD ["/bin/bash"]