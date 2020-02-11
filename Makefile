# version
VERSION := 0.1

# set bash as default interpreter
SHELL := /bin/bash

# date.time as build number
BUILD_NUMBER := $(or ${BUILD_NUMBER},$(shell date '+%Y%m%d.%H%M%S'))

# set docker user credentials
DOCKER_USER := $(or ${DOCKER_USER},${USER})
DOCKER_PASSWORD := ${DOCKER_PASSWORD}

# use DockerHub as default registry
DOCKER_REGISTRY := $(or ${DOCKER_REGISTRY},registry.hub.docker.com)

# set Docker repository
DOCKER_REPOSITORY_OWNER := $(or ${DOCKER_REPOSITORY_OWNER},${DOCKER_USER})
#DOCKER_IMAGE_PREFIX ?= deephealth-
runtime_suffix = 
develop_suffix = -toolkit

# latest tag settings
DOCKER_IMAGE_LATEST := $(or ${DOCKER_IMAGE_LATEST},false)

# extra tags
DOCKER_IMAGE_TAG_EXTRA := ${DOCKER_IMAGE_TAG_EXTRA}

# set default Docker image TAG
DOCKER_IMAGE_TAG := $(or ${DOCKER_IMAGE_TAG},${BUILD_NUMBER})

# set default Base images
DOCKER_BASE_IMAGE_SKIP_PULL := $(or ${DOCKER_BASE_IMAGE_SKIP_PULL},true)
DOCKER_BASE_IMAGE_VERSION_TAG := $(or ${DOCKER_BASE_IMAGE_VERSION_TAG},${DOCKER_IMAGE_TAG})
DOCKER_NVIDIA_DEVELOP_IMAGE := $(or ${DOCKER_NVIDIA_DEVELOP_IMAGE},nvidia/cuda:10.1-devel)
DOCKER_NVIDIA_RUNTIME_IMAGE := $(or ${DOCKER_NVIDIA_RUNTIME_IMAGE},nvidia/cuda:10.1-runtime)

# current path
CURRENT_PATH := $(PWD)

# libraries path
LOCAL_LIBS_PATH = libs
LOCAL_PYLIBS_PATH = pylibs
ECVL_LIB_PATH = ${LOCAL_LIBS_PATH}/ecvl
EDDL_LIB_PATH = ${LOCAL_LIBS_PATH}/eddl
PYECVL_LIB_PATH = ${LOCAL_PYLIBS_PATH}/pyecvl
PYEDDL_LIB_PATH = ${LOCAL_PYLIBS_PATH}/pyeddl

# ECVL repository
ECVL_REPOSITORY := $(or ${ECVL_REPOSITORY},https://github.com/deephealthproject/ecvl.git)
ECVL_BRANCH := $(or ${ECVL_BRANCH},master)
ECVL_REVISION := ${ECVL_REVISION}

# PyECVL repository
PYECVL_REPOSITORY := $(or ${PYECVL_REPOSITORY},https://github.com/deephealthproject/pyecvl.git)
PYECVL_BRANCH := $(or ${PYECVL_BRANCH},master)
PYECVL_REVISION := ${PYECVL_REVISION}

# EDDL repository
EDDL_REPOSITORY := $(or ${EDDL_REPOSITORY},https://github.com/deephealthproject/eddl.git)
EDDL_BRANCH := $(or ${EDDL_BRANCH},master)
EDDL_REVISION := ${EDDL_REVISION}

# PyEDDL repository
PYEDDL_REPOSITORY := $(or ${PYEDDL_REPOSITORY},https://github.com/deephealthproject/pyeddl.git)
PYEDDL_BRANCH := $(or ${PYEDDL_BRANCH},master)
PYEDDL_REVISION := ${PYEDDL_REVISION}

# config file
CONFIG_FILE ?= settings.sh
ifneq ($(wildcard $(CONFIG_FILE)),)
include $(CONFIG_FILE)
endif

# set no cache option
DISABLE_CACHE ?= 
BUILD_CACHE_OPT ?= 
ifneq ("$(DISABLE_CACHE)", "")
BUILD_CACHE_OPT = --no-cache
endif

# enable latest tags
push_latest_tags = false
ifeq ("${DOCKER_IMAGE_LATEST}", "true")
	push_latest_tags = true
endif

# auxiliary flag 
DOCKER_LOGIN_DONE := $(or ${DOCKER_LOGIN_DONE},false)

#
define build_image
	$(eval image := $(1))
	$(eval target := $(2))
	$(eval labels := $(3))
	$(eval base := $(if $(4), --build-arg BASE_IMAGE=$(4)))
	$(eval toolkit := $(if $(5), --build-arg TOOLKIT_IMAGE=$(5)))
	$(eval extra_tag := $(if $(6), -t ${image_name}:${6}))
	$(eval image_name := ${DOCKER_IMAGE_PREFIX}${target}${${target}_suffix})
	$(eval latest_tags := $(shell if [ "${push_latest_tags}" == "true" ]; then echo "-t ${image_name}:latest"; fi))
	@echo "Building Docker image '${image_name}'..."
	cd ${image} \
	&& docker build ${BUILD_CACHE_OPT} \
		-f ${target}.Dockerfile \
		   ${base} ${toolkit} \
		-t ${image_name}:${DOCKER_IMAGE_TAG} ${extra_tag} ${latest_tags} ${labels} .
endef

define push_image
	$(eval image := $(1))
	$(eval image_name := ${DOCKER_IMAGE_PREFIX}${image})
	$(eval full_image_name := $(shell prefix=""; if [ -n "${DOCKER_REGISTRY}" ]; then prefix="${DOCKER_REGISTRY}/"; fi; echo "${prefix}${DOCKER_REPOSITORY_OWNER}/${image_name}"))
	$(eval full_tag := ${full_image_name}:$(DOCKER_IMAGE_TAG))
	$(eval latest_tag := ${full_image_name}:latest)
	$(eval tags := ${DOCKER_IMAGE_TAG_EXTRA})
	@echo "Tagging images... "
	docker tag ${image_name}:$(DOCKER_IMAGE_TAG) ${full_tag}
	@if [ ${push_latest_tags} == true ]; then docker tag ${image_name}:$(DOCKER_IMAGE_TAG) ${latest_tag}; fi
	@echo "Pushing Docker image '${image_name}'..."	
	docker push ${full_tag}
	@if [ ${push_latest_tags} == true ]; then docker push ${latest_tag}; fi
	@for tag in $(tags); \
	do \
	img_tag=${full_image_name}:$$tag ; \
	docker tag ${full_tag} $$img_tag ; \
	docker push $$img_tag ; \
	done
endef

# 1 --> LIB_PATH
# 2 --> REPOSITORY
# 3 --> BRANCH
# 4 --> REVISION
# 5 --> RECURSIVE SUBMODULE CLONE (true|false)
define clone_repository
	if [ ! -d ${1} ]; then \
		git clone --branch "${3}" ${2} ${1} \
		&& cd "${1}" \
		&& if [ -n "${4}" ]; then git reset --hard ${4} -- ; fi \
		&& if [ ${5} == true ]; then git submodule update --init --recursive ; fi \
		&& cd - \
	else \
		echo "Using existing ${1} repository..." ;  \
	fi
endef


define clean_sources
	$(eval path := $(1))
	@printf "Removing sources '$(path)'... "
	@rm -rf $(path)
	@printf "DONE\n"	
endef


define clean_image
	$(eval image := $(1))
	@printf "Stopping docker containers instances of image '$(image)'... "
	@docker ps -a | grep -E "^$(image)\s" | awk '{print $$1}' | xargs docker rm -f  || true
	@printf "DONE\n"
	@printf "Removing docker image '$(image)'... "
	@docker images | grep -E "^$(image)\s" | awk '{print $$1 ":" $$2}' | xargs docker rmi -f  || true	
	@printf "DONE\n"
	@printf "Removing unused docker image... "
	@docker image prune -f
	@printf "DONE\n"
endef


# 1: library path
# 2: actual revision
define get_revision	
$(shell if [[ -z "${2}" ]]; then cd ${1} && git rev-parse HEAD; else echo "${2}" ; fi)
endef

.DEFAULT_GOAL := help

help: ## Show help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

libs_folder:
	$(if $(wildcard ${LOCAL_LIBS_PATH}),, \
		$(info Creating ${LOCAL_LIBS_PATH} folder...) ; \
		@mkdir -p ${LOCAL_LIBS_PATH} ; \
	)

eddl_folder: libs_folder	
	@$(if $(wildcard ${EDDL_LIB_PATH}),$(info Using existing '${EDDL_LIB_PATH}' repository), \
		$(call clone_repository,${EDDL_LIB_PATH},${EDDL_REPOSITORY},${EDDL_BRANCH},${EDDL_REVISION},true) ; \
	)


define clone_ecvl
	$(if $(wildcard ${ECVL_LIB_PATH}),$(info Using existing '${ECVL_LIB_PATH}' repository), \
		$(call clone_repository,${ECVL_LIB_PATH},${ECVL_REPOSITORY},${ECVL_BRANCH},${ECVL_REVISION},true) ; \
	)
endef

ecvl_folder: libs_folder
	$(call clone_ecvl)

pylibs_folder:
	@mkdir -p ${LOCAL_PYLIBS_PATH}

define pyeddl_shallow_clone
	$(if $(wildcard ${PYEDDL_LIB_PATH}),$(info Using existing '${PYEDDL_LIB_PATH}' repository), \
		$(call clone_repository,${PYEDDL_LIB_PATH},${PYEDDL_REPOSITORY},${PYEDDL_BRANCH},${PYEDDL_REVISION},false) ; \
	)
endef

define pyeddl_clone_dependencies
	$(eval EDDL_REVISION = $(shell if [[ ! -n "${EDDL_REVISION}" ]]; then cd ${CURRENT_PATH}/${PYEDDL_LIB_PATH} && git submodule status -- third_party/eddl | sed -E 's/-//; s/ .*//'; else echo ${EDDL_REVISION}; fi))
	@echo "EDDL_REVISION: ${EDDL_REVISION}"
	@if [[ -d ${EDDL_LIB_PATH} ]]; then \
		echo "Using existing '${EDDL_LIB_PATH}' repository" ; \
	else \
		$(call clone_repository,${EDDL_LIB_PATH},${EDDL_REPOSITORY},${EDDL_BRANCH},${EDDL_REVISION},true) ; \
		printf "Copying revision '${EDDL_REVISION}' of EDDL library... " ; \
		rm -rf ${PYEDDL_LIB_PATH}/third_party/eddl && cp -a ${EDDL_LIB_PATH} ${PYEDDL_LIB_PATH}/third_party/eddl ; \
		printf "DONE\n" ; \
	fi	
endef

_pyeddl_shallow_clone: pylibs_folder
	@$(call pyeddl_shallow_clone)

pyeddl_folder: _pyeddl_shallow_clone
	$(call pyeddl_clone_dependencies)

define pyecvl_shallow_clone
	@$(if $(wildcard ${PYECVL_LIB_PATH}),$(info Using existing '${PYECVL_LIB_PATH}' repository), \
		$(call clone_repository,${PYECVL_LIB_PATH},${PYECVL_REPOSITORY},${PYECVL_BRANCH},${PYECVL_REVISION},false) ; \
	)
endef

define pyecvl_resolve_dependencies
	$(eval PYEDDL_REVISION = $(shell if [[ ! -n "${PYEDDL_REVISION}" ]]; then cd ${CURRENT_PATH}/${PYECVL_LIB_PATH} && git submodule status -- third_party/pyeddl | sed -E 's/-//; s/ .*//'; else echo ${PYEDDL_REVISION}; fi))
	$(eval ECVL_REVISION = $(shell if [[ ! -n "${ECVL_REVISION}" ]]; then cd ${CURRENT_PATH}/${PYECVL_LIB_PATH} && git submodule status -- third_party/ecvl | sed -E 's/-//; s/ .*//'; else echo ${ECVL_REVISION}; fi))
	@if [[ -d ${PYEDDL_LIB_PATH} ]]; then \
		echo "Using existing '${PYEDDL_LIB_PATH}' repository" ; \
	else \
		$(call pyeddl_shallow_clone) \
		printf "Copying revision '${PYEDDL_REVISION}' of PYEDDL library... " ; \
		rm -rf ${PYECVL_LIB_PATH}/third_party/pyeddl && cp -a ${PYEDDL_LIB_PATH} ${PYECVL_LIB_PATH}/third_party/pyeddl ; \
		printf "DONE\n" ; \
	fi
	@if [[ -d ${ECVL_LIB_PATH} ]]; then \
		echo "Using existing '${ECVL_LIB_PATH}' repository" ; \
	else \
		echo "Using ECVL revision '${ECVL_REVISION}'" ; \
		$(call clone_ecvl) \
		printf "Copying revision '${ECVL_REVISION}' of ECVL library... " ; \
		rm -rf ${PYECVL_LIB_PATH}/third_party/ecvl && cp -a ${ECVL_LIB_PATH} ${PYECVL_LIB_PATH}/third_party/ecvl ; \
		printf "DONE\n" ; \
	fi
endef

_pyecvl_shallow_clone: pylibs_folder
	$(call pyecvl_shallow_clone)

_pyecvl_first_level_dependencies: _pyecvl_shallow_clone
	$(call pyecvl_resolve_dependencies)

_pyecvl_second_level_dependencies: _pyecvl_first_level_dependencies
	$(call pyeddl_clone_dependencies)

pyecvl_folder: _pyecvl_second_level_dependencies


# TODO: remove this patch when not required
apply_pyeddl_patches:	
	@echo "Applying patches to the EDDL repository..."
	$(call clone_repository,${PYEDDL_LIB_PATH},${PYEDDL_REPOSITORY},${PYEDDL_BRANCH},${PYEDDL_REVISION},false)
	cd ${EDDL_LIB_PATH} && git apply ../../${PYEDDL_LIB_PATH}/eddl_0.3.patch || true
	# @echo "Copying revision '${EDDL_REVISION}' of EDDL library..."
	# @rm -rf ${PYEDDL_LIB_PATH}/third_party/eddl
	# @cp -a ${EDDL_LIB_PATH} ${PYEDDL_LIB_PATH}/third_party/eddl

# # TODO: remove this patch when not required
apply_pyecvl_patches:


#####################################################################################################################################
############# Build Docker images #############
#####################################################################################################################################
# Targets to build container images
build: _build ## Build libs+pylibs Docker images
_build: \
	build_libs \
	build_libs_toolkit \
	build_pylibs \
	build_pylibs_toolkit


############# libs-toolkit #############

_build_libs_base_toolkit:
	$(eval base_image := libs-base-toolkit:${DOCKER_BASE_IMAGE_VERSION_TAG})
	$(eval images := $(shell docker images -q ${base_image}))
	$(if ${images},\
		@echo "Using existing image '${base_image}'..."; \
		if [ "${DOCKER_BASE_IMAGE_SKIP_PULL}" != "true" ]; then \
		echo "Pulling the latest version of '${base_image}'..."; \
		docker pull -q ${base_image} ; fi ; , \
		$(call build_image,libs,libs-base-toolkit,,$(DOCKER_NVIDIA_DEVELOP_IMAGE))\
	)

build_eddl_toolkit: eddl_folder _build_libs_base_toolkit apply_pyeddl_patches ## Build 'eddl-toolkit' image
	$(call build_image,libs,eddl-toolkit,\
		--label CONTAINER_VERSION=${DOCKER_IMAGE_TAG} \
		--label EDDL_REPOSITORY=${EDDL_REPOSITORY} \
		--label EDDL_BRANCH=${EDDL_BRANCH} \
		--label EDDL_REVISION=$(call get_revision,${EDDL_LIB_PATH},${EDDL_REVISION}),libs-base-toolkit:$(DOCKER_BASE_IMAGE_VERSION_TAG))

build_ecvl_toolkit: ecvl_folder build_eddl_toolkit ## Build 'ecvl-toolkit' image
	$(call build_image,libs,ecvl-toolkit,\
		--label CONTAINER_VERSION=${DOCKER_IMAGE_TAG} \
		--label ECVL_REPOSITORY=${ECVL_REPOSITORY} \
		--label ECVL_BRANCH=${ECVL_BRANCH} \
		--label ECVL_REVISION=$(call get_revision,${ECVL_LIB_PATH},${ECVL_REVISION}),eddl-toolkit:$(DOCKER_IMAGE_TAG))

build_libs_toolkit: build_ecvl_toolkit ## Build 'libs-toolkit' image
	$(call build_image,libs,libs-toolkit,\
		--label CONTAINER_VERSION=${DOCKER_IMAGE_TAG} \
		--label EDDL_REPOSITORY=${EDDL_REPOSITORY} \
		--label EDDL_BRANCH=${EDDL_BRANCH} \
		--label EDDL_REVISION=$(call get_revision,${EDDL_LIB_PATH},${EDDL_REVISION}) \
		--label ECVL_REPOSITORY=${ECVL_REPOSITORY} \
		--label ECVL_BRANCH=${ECVL_BRANCH} \
		--label ECVL_REVISION=$(call get_revision,${ECVL_LIB_PATH},${ECVL_REVISION}),ecvl-toolkit:$(DOCKER_IMAGE_TAG))



############# libs #############

_build_libs_base: 
	$(eval base_image := libs-base:${DOCKER_BASE_IMAGE_VERSION_TAG})
	$(eval images := $(shell docker images -q ${base_image}))
	$(if ${images},\
		@echo "Using existing image '${base_image}'..."; \
		if [ "${DOCKER_BASE_IMAGE_SKIP_PULL}" != "true" ]; then \
		echo "Pulling the latest version of '${base_image}'..."; \
		docker pull -q ${base_image} ; fi ; , \
		$(call build_image,libs,libs-base,,$(DOCKER_NVIDIA_RUNTIME_IMAGE)) \
	)

build_eddl: _build_libs_base build_eddl_toolkit ## Build 'eddl' image
	$(call build_image,libs,eddl,\
		--label CONTAINER_VERSION=${DOCKER_IMAGE_TAG} \
		--label EDDL_REPOSITORY=${EDDL_REPOSITORY} \
		--label EDDL_BRANCH=${EDDL_BRANCH} \
		--label EDDL_REVISION=$(call get_revision,${EDDL_LIB_PATH},${EDDL_REVISION}),libs-base:$(DOCKER_BASE_IMAGE_VERSION_TAG),eddl-toolkit:$(DOCKER_IMAGE_TAG))

build_ecvl: _build_libs_base build_ecvl_toolkit## Build 'ecvl' image
	$(call build_image,libs,ecvl,\
		--label CONTAINER_VERSION=${DOCKER_IMAGE_TAG} \
		--label EDDL_REPOSITORY=${EDDL_REPOSITORY} \
		--label EDDL_BRANCH=${EDDL_BRANCH} \
		--label EDDL_REVISION=$(call get_revision,${EDDL_LIB_PATH},${EDDL_REVISION}) \
		--label ECVL_REPOSITORY=${ECVL_REPOSITORY} \
		--label ECVL_BRANCH=${ECVL_BRANCH} \
		--label ECVL_REVISION=$(call get_revision,${ECVL_LIB_PATH},${ECVL_REVISION}),eddl:$(DOCKER_IMAGE_TAG),ecvl-toolkit:$(DOCKER_IMAGE_TAG))

build_libs: build_ecvl ## Build 'libs' image
	$(call build_image,libs,libs,\
		--label CONTAINER_VERSION=${DOCKER_IMAGE_TAG} \
		--label EDDL_REPOSITORY=${EDDL_REPOSITORY} \
		--label EDDL_BRANCH=${EDDL_BRANCH} \
		--label EDDL_REVISION=$(call get_revision,${EDDL_LIB_PATH},${EDDL_REVISION}) \
		--label ECVL_REPOSITORY=${ECVL_REPOSITORY} \
		--label ECVL_BRANCH=${ECVL_BRANCH} \
		--label ECVL_REVISION=$(call get_revision,${ECVL_LIB_PATH},${ECVL_REVISION}),ecvl:$(DOCKER_IMAGE_TAG))



############# pylibs-toolkit #############

_build_pylibs_base_toolkit: build_libs_toolkit	
	$(eval base_image := pylibs-toolkit.base:${DOCKER_BASE_IMAGE_VERSION_TAG})
	$(eval images := $(shell docker images -q ${base_image}))
	$(if ${images},\
		@echo "Using existing image '${base_image}'..."; \
		if [ "${DOCKER_BASE_IMAGE_SKIP_PULL}" != "true" ]; then \
		echo "Pulling the latest version of '${base_image}'..."; \
		docker pull -q ${base_image} ; fi ; , \
		$(call build_image,pylibs,pylibs-base-toolkit,,libs-toolkit:$(DOCKER_IMAGE_TAG)) \
	)

build_pyeddl_toolkit: pyeddl_folder _build_pylibs_base_toolkit ## Build 'pyeddl-toolkit' image
	$(call build_image,pylibs,pyeddl-toolkit,\
		--label CONTAINER_VERSION=${DOCKER_IMAGE_TAG} \
		--label EDDL_REPOSITORY=${EDDL_REPOSITORY} \
		--label EDDL_BRANCH=${EDDL_BRANCH} \
		--label EDDL_REVISION=$(call get_revision,${EDDL_LIB_PATH},${EDDL_REVISION}) \
		--label ECVL_REPOSITORY=${ECVL_REPOSITORY} \
		--label ECVL_BRANCH=${ECVL_BRANCH} \
		--label ECVL_REVISION=$(call get_revision,${ECVL_LIB_PATH},${ECVL_REVISION}) \
		--label PYEDDL_REPOSITORY=${PYEDDL_REPOSITORY} \
		--label PYEDDL_BRANCH=${PYEDDL_BRANCH} \
		--label PYEDDL_REVISION=$(call get_revision,${PYEDDL_LIB_PATH},${PYEDDL_REVISION}),pylibs-base-toolkit:$(DOCKER_IMAGE_TAG))

build_pyecvl_toolkit: pyecvl_folder build_pyeddl_toolkit ## Build 'pyecvl-toolkit' image
	$(call build_image,pylibs,pyecvl-toolkit,\
		--label CONTAINER_VERSION=${DOCKER_IMAGE_TAG} \
		--label EDDL_REPOSITORY=${EDDL_REPOSITORY} \
		--label EDDL_BRANCH=${EDDL_BRANCH} \
		--label EDDL_REVISION=$(call get_revision,${EDDL_LIB_PATH},${EDDL_REVISION}) \
		--label ECVL_REPOSITORY=${ECVL_REPOSITORY} \
		--label ECVL_BRANCH=${ECVL_BRANCH} \
		--label ECVL_REVISION=$(call get_revision,${ECVL_LIB_PATH},${ECVL_REVISION}) \
		--label PYECVL_REPOSITORY=${PYECVL_REPOSITORY} \
		--label PYECVL_BRANCH=${PYECVL_BRANCH} \
		--label PYECVL_REVISION=$(call get_revision,${PYECVL_LIB_PATH},${PYECVL_REVISION}) \
		--label PYEDDL_REPOSITORY=${PYEDDL_REPOSITORY} \
		--label PYEDDL_BRANCH=${PYEDDL_BRANCH} \
		--label PYEDDL_REVISION=$(call get_revision,${PYEDDL_LIB_PATH},${PYEDDL_REVISION}),pyeddl-toolkit:$(DOCKER_IMAGE_TAG))

build_pylibs_toolkit: build_pyecvl_toolkit ## Build 'pylibs-toolkit' image
	$(call build_image,pylibs,pylibs-toolkit,\
		--label CONTAINER_VERSION=${DOCKER_IMAGE_TAG} \
		--label EDDL_REPOSITORY=${EDDL_REPOSITORY} \
		--label EDDL_BRANCH=${EDDL_BRANCH} \
		--label EDDL_REVISION=$(call get_revision,${EDDL_LIB_PATH},${EDDL_REVISION}) \
		--label ECVL_REPOSITORY=${ECVL_REPOSITORY} \
		--label ECVL_BRANCH=${ECVL_BRANCH} \
		--label ECVL_REVISION=$(call get_revision,${ECVL_LIB_PATH},${ECVL_REVISION}) \
		--label PYECVL_REPOSITORY=${PYECVL_REPOSITORY} \
		--label PYECVL_BRANCH=${PYECVL_BRANCH} \
		--label PYECVL_REVISION=$(call get_revision,${PYECVL_LIB_PATH},${PYECVL_REVISION}) \
		--label PYEDDL_REPOSITORY=${PYEDDL_REPOSITORY} \
		--label PYEDDL_BRANCH=${PYEDDL_BRANCH} \
		--label PYEDDL_REVISION=$(call get_revision,${PYEDDL_LIB_PATH},${PYEDDL_REVISION}),pyecvl-toolkit:$(DOCKER_IMAGE_TAG))



############# pylibs #############

_build_pylibs_base: _build_libs_base
	$(eval base_image := pylibs-base:${DOCKER_BASE_IMAGE_VERSION_TAG})
	$(eval images := $(shell docker images -q ${base_image}))
	$(if ${images},\
		@echo "Using existing image '${base_image}'..."; \
		if [ "${DOCKER_BASE_IMAGE_SKIP_PULL}" != "true" ]; then \
		echo "Pulling the latest version of '${base_image}'..."; \
		docker pull -q ${base_image} ; fi ; , \
		$(call build_image,pylibs,pylibs-base,,libs:$(DOCKER_IMAGE_TAG)) \
	)

build_pyeddl: _build_pylibs_base build_pyeddl_toolkit ## Build 'pyeddl' image
	$(call build_image,pylibs,pyeddl,\
		--label EDDL_REPOSITORY=${EDDL_REPOSITORY} \
		--label EDDL_BRANCH=${EDDL_BRANCH} \
		--label EDDL_REVISION=$(call get_revision,${EDDL_LIB_PATH},${EDDL_REVISION}) \
		--label ECVL_REPOSITORY=${ECVL_REPOSITORY} \
		--label ECVL_BRANCH=${ECVL_BRANCH} \
		--label ECVL_REVISION=$(call get_revision,${ECVL_LIB_PATH},${ECVL_REVISION}) \
		--label PYEDDL_REPOSITORY=${PYEDDL_REPOSITORY} \
		--label PYEDDL_BRANCH=${PYEDDL_BRANCH} \
		--label PYEDDL_REVISION=$(call get_revision,${PYEDDL_LIB_PATH},${PYEDDL_REVISION}),pylibs-base:$(DOCKER_IMAGE_TAG),pyeddl-toolkit:$(DOCKER_IMAGE_TAG))

build_pyecvl: build_pyeddl build_pyecvl_toolkit ## Build 'pyecvl' image
	$(call build_image,pylibs,pyecvl,\
		--label EDDL_REPOSITORY=${EDDL_REPOSITORY} \
		--label EDDL_BRANCH=${EDDL_BRANCH} \
		--label EDDL_REVISION=$(call get_revision,${EDDL_LIB_PATH},${EDDL_REVISION}) \
		--label ECVL_REPOSITORY=${ECVL_REPOSITORY} \
		--label ECVL_BRANCH=${ECVL_BRANCH} \
		--label ECVL_REVISION=$(call get_revision,${ECVL_LIB_PATH},${ECVL_REVISION}) \
		--label PYECVL_REPOSITORY=${PYECVL_REPOSITORY} \
		--label PYECVL_BRANCH=${PYECVL_BRANCH} \
		--label PYECVL_REVISION=$(call get_revision,${PYECVL_LIB_PATH},${PYECVL_REVISION}) \
		--label PYEDDL_REPOSITORY=${PYEDDL_REPOSITORY} \
		--label PYEDDL_BRANCH=${PYEDDL_BRANCH} \
		--label PYEDDL_REVISION=$(call get_revision,${PYEDDL_LIB_PATH},${PYEDDL_REVISION}),pyeddl:$(DOCKER_IMAGE_TAG),pyecvl-toolkit:$(DOCKER_IMAGE_TAG))

build_pylibs: build_pyecvl ## Build 'pylibs' image
	$(call build_image,pylibs,pylibs,\
		--label EDDL_REPOSITORY=${EDDL_REPOSITORY} \
		--label EDDL_BRANCH=${EDDL_BRANCH} \
		--label EDDL_REVISION=$(call get_revision,${EDDL_LIB_PATH},${EDDL_REVISION}) \
		--label ECVL_REPOSITORY=${ECVL_REPOSITORY} \
		--label ECVL_BRANCH=${ECVL_BRANCH} \
		--label ECVL_REVISION=$(call get_revision,${ECVL_LIB_PATH},${ECVL_REVISION}) \
		--label PYECVL_REPOSITORY=${PYECVL_REPOSITORY} \
		--label PYECVL_BRANCH=${PYECVL_BRANCH} \
		--label PYECVL_REVISION=$(call get_revision,${PYECVL_LIB_PATH},${PYECVL_REVISION}) \
		--label PYEDDL_REPOSITORY=${PYEDDL_REPOSITORY} \
		--label PYEDDL_BRANCH=${PYEDDL_BRANCH} \
		--label PYEDDL_REVISION=$(call get_revision,${PYEDDL_LIB_PATH},${PYEDDL_REVISION}),pyecvl:$(DOCKER_IMAGE_TAG))

############################################################################################################################
### Push Docker images
############################################################################################################################
push: _push ## Push all built images
_push: \
	push_libs_toolkit push_libs \
	push_pylibs_toolkit push_pylibs 

push_libs: repo-login ## Push 'libs' images
	$(call push_image,libs)

push_eddl: repo-login ## Push 'eddl' images
	$(call push_image,eddl)

push_ecvl: repo-login ## Push 'ecvl' images
	$(call push_image,ecvl)

push_libs_toolkit: repo-login ## Push 'libs-toolkit' images
	$(call push_image,libs-toolkit)

push_eddl_toolkit: repo-login ## Push 'eddl-toolkit' images
	$(call push_image,eddl-toolkit)

push_ecvl_toolkit: repo-login ## Push 'ecvl-toolkit' images
	$(call push_image,ecvl-toolkit)

push_pylibs: repo-login ## Push 'pylibs' images
	$(call push_image,pylibs)

push_pyeddl: repo-login ## Push 'pyeddl' images
	$(call push_image,pyeddl)

push_pyecvl: repo-login ## Push 'pyecvl' images
	$(call push_image,pyecvl)

push_pylibs_toolkit: repo-login ## Push 'pylibs-toolkit' images
	$(call push_image,pylibs-toolkit)

push_pyeddl_toolkit: repo-login ## Push 'pyeddl-toolkit' images
	$(call push_image,pyeddl-toolkit)

push_pyecvl_toolkit: repo-login ## Push 'pyeddl-toolkit' images
	$(call push_image,pyecvl-toolkit)

############################################################################################################################
### Piblish Docker images
############################################################################################################################
publish: build push ## Publish all built images to a Docker Registry (e.g., DockerHub)

publish_libs: build_libs push_libs ## Publish 'libs' images

publish_eddl: build_eddl push_eddl ## Publish 'eddl' images

publish_ecvl: build_ecvl push_ecvl ## Publish 'ecvl' images

publish_libs_toolkit: build_libs_toolkit push_libs_toolkit ## Publish 'libs-toolkit' images

publish_eddl_toolkit: build_eddl_toolkit push_eddl_toolkit ## Publish 'eddl-toolkit' images

publish_ecvl_toolkit: build_ecvl_toolkit push_ecvl_toolkit ## Publish 'ecvl-toolkit' images

publish_pylibs: build_pylibs push_pylibs ## Publish 'pylibs' images

publish_pyeddl: build_pyeddl push_pyeddl ## Publish 'pyeddl' images

publish_pyecvl: build_pyecvl push_pyecvl ## Publish 'pyecvl' images

publish_pylibs_toolkit: build_pylibs_toolkit push_pylibs_toolkit ## Publish 'pylibs-toolkit' images

publish_pyeddl_toolkit: build_pyeddl_toolkit push_pyeddl_toolkit ## Publish 'pyeddl-toolkit' images

publish_pyecvl_toolkit: build_pyecvl_toolkit push_pyecvl_toolkit ## Publish 'pyecvl-toolkit' images

# login to the Docker HUB repository
repo-login: ## Login to the Docker Registry
	@if [[ ${DOCKER_LOGIN_DONE} == false ]]; then \
		echo "Logging into Docker registry ${DOCKER_REGISTRY}..." ; \
		docker login ${DOCKER_REGISTRY} -u ${DOCKER_USER} -p ${DOCKER_PASSWORD} ; \
		DOCKER_LOGIN_DONE=true ;\
	else \
		echo "Logging into Docker registry already done" ; \
	fi

version: ## Output the current version of this Makefile
	@echo $(VERSION)


############################################################################################################################
### Clean sources
############################################################################################################################
clean_eddl_sources:
	$(call clean_sources,libs/eddl)

clean_ecvl_sources:
	$(call clean_sources,libs/ecvl)

clean_pyeddl_sources:
	$(call clean_sources,pylibs/pyeddl)

clean_pyecvl_sources:
	$(call clean_sources,pylibs/pyecvl)

clean_libs_sources: clean_eddl_sources clean_ecvl_sources

clean_pylibs_sources: clean_pyeddl_sources clean_pyecvl_sources

clean_sources: clean_pylibs_sources clean_libs_sources


############################################################################################################################
### Clean Docker images
############################################################################################################################
clean_base_images:
	$(call clean_image,libs-base)
	$(call clean_image,pylibs-base)
	$(call clean_image,libs-base-toolkit)
	$(call clean_image,pylibs-base-toolkit)

clean_eddl_images:
	$(call clean_image,eddl)
	$(call clean_image,eddl-toolkit)

clean_ecvl_images:
	$(call clean_image,ecvl)
	$(call clean_image,ecvl-toolkit)

clean_libs_images: clean_ecvl_images clean_eddl_images
	$(call clean_image,libs)
	$(call clean_image,libs-toolkit)

clean_pyeddl_images:
	$(call clean_image,pyeddl)
	$(call clean_image,pyeddl-toolkit)

clean_pyecvl_images:
	$(call clean_image,pyecvl)
	$(call clean_image,pyecvl-toolkit)

clean_pylibs_images: clean_pyecvl_images clean_pyeddl_images
	$(call clean_image,pylibs)
	$(call clean_image,pylibs-toolkit)

clean_images: clean_pylibs_images clean_libs_images clean_base_images


############################################################################################################################
### Clean Docker images
############################################################################################################################
clean: clean_images clean_sources



.PHONY: help \
	libs_folder eddl_folder ecvl_folder pylibs_folder \
	pyeddl_folder _pyeddl_shallow_clone \
	pyecvl_folder _pyeddl_shallow_clone _pyecvl_first_level_dependencies _pyecvl_second_level_dependencies \
	apply_pyeddl_patches apply_pyecvl_patches \
	clean clean_libs clean_pylibs apply_libs_patches \
	build _build \
	_build_libs_base_toolkit \
	build_eddl_toolkit build_ecvl_toolkit build_libs_toolkit \
	_build_libs_base build_eddl build_ecvl build_libs \
	_build_pylibs_base_toolkit _build_pylibs_base \
	build_pyeddl_toolkit build_pyecvl_toolkit build_pylibs_toolkit\
	_build_pylibs_base build_pyeddl build_pyecvl build_pylibs \
	repo-login \
	push _push \
	push_libs push_eddl push_ecvl \
	push_libs_toolkit push_eddl_toolkit push_ecvl_toolkit \
	push_pylibs push_pyeddl push_pyecvl \
	push_pylibs_toolkit push_pyeddl_toolkit push_pyecvl_toolkit \
	publish \
	publish_libs publish_eddl publish_ecvl \
	publish_libs_toolkit publish_eddl_toolkit publish_ecvl_toolkit \
	publish_pylibs publish_pyeddl publish_pyecvl \
	publish_pylibs_toolkit publish_pyeddl_toolkit publish_pyecvl_toolkit \
	clean_sources \
	clean_eddl_sources clean_ecvl_sources \
	clean_pyeddl_sources clean_pyecvl_sources \
	clean \
	clean_images \
	clean_base_images \
	clean_eddl_images clean_ecvl_images clean_libs_images \
	clean_pyeddl_images clean_pyecvl_images clean_pylibs_images