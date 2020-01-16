pipeline {
  agent any
  triggers{
    upstream(
      upstreamProjects: 'DeepHealth/eddl/master,DeepHealth/ecvl/master,DeepHealth/pyeddl/master,DeepHealth/pyecvl/master',
      threshold: hudson.model.Result.SUCCESS)
  }
  environment {
    BASE_SRC = "/usr/local/src"
    ECVL_SRC = "${BASE_SRC}/ecvl"
    EDDL_SRC = "${BASE_SRC}/eddl"
    PYECVL_SRC = "${BASE_SRC}/pyecvl"
    PYEDDL_SRC = "${BASE_SRC}/pyeddl"
    // ECVL Settings
    ECVL_REPOSITORY = "https://github.com/deephealthproject/ecvl.git"
    ECVL_BRANCH = "master"
    ECVL_REVISION = sh(returnStdout: true, script: "git ls-remote ${ECVL_REPOSITORY} ${ECVL_BRANCH} | awk '{print \$1}'").trim()
    // PyECVL Settings
    PYECVL_REPOSITORY = "https://github.com/deephealthproject/pyecvl.git"
    PYECVL_BRANCH = "master"
    PYECVL_REVISION = sh(returnStdout: true, script: "git ls-remote ${PYECVL_REPOSITORY} ${PYECVL_BRANCH} | awk '{print \$1}'").trim()
    // EDDL Settings    
    EDDL_REPOSITORY = "https://github.com/deephealthproject/eddl.git"
    EDDL_BRANCH = "master"
    EDDL_REVISION = sh(returnStdout: true, script: "git ls-remote ${EDDL_REPOSITORY} ${EDDL_BRANCH} | awk '{print \$1}'").trim()
    // PyEDDL Settings
    PYEDDL_REPOSITORY = "https://github.com/deephealthproject/pyeddl.git"
    PYEDDL_BRANCH = "master"
    PYEDDL_REVISION = sh(returnStdout: true, script: "git ls-remote ${PYEDDL_REPOSITORY} ${PYEDDL_BRANCH} | awk '{print \$1}'").trim()
    // Docker Settings
    DOCKER_IMAGE_LATEST = sh(returnStdout: true, script: "if [ \"${GIT_BRANCH}\" == 'master' ]; then echo 'true'; else echo 'false'; fi").trim()
    DOCKER_IMAGE_TAG = sh(returnStdout: true, script: "if [ \"${GIT_BRANCH}\" == 'master' ]; then echo '${BUILD_NUMBER}' ; else echo '${BUILD_NUMBER}-dev' ; fi").trim()
    // Docker credentials
    registryCredential = 'dockerhub-deephealthproject'
    // Skip DockerHub
    DOCKER_LOGIN_DONE = true
  }
  stages {

    stage('Configure') {
      steps {
        sh 'git fetch --tags'
        sh 'printenv'
      }
    }
    
    stage('Development Build') {
      when {
          not { branch "master" }
      }
      steps {        
        sh 'CONFIG_FILE="" make build'
      }
    }

    stage('Master Build') {
      when {
          branch 'master'
      }
      steps {
        sh 'make build'
      }
    }

    stage('Test EDDL') {
      agent {
        docker { image 'libs-toolkit:${DOCKER_IMAGE_TAG}' }
      }
      steps {
        sh 'cd ${EDDL_SRC}/build && ctest -C Debug -VV'
      }
    }

    stage('Test ECVL') {
      agent {
        docker { image 'libs-toolkit:${DOCKER_IMAGE_TAG}' }
      }
      steps {
        sh 'cd ${ECVL_SRC}/build && ctest -C Debug -VV'
      }
    }

    stage('Test PyEDDL') {
      agent {
        docker { image 'pylibs-toolkit:${DOCKER_IMAGE_TAG}' }
      }
      steps {
        sh 'cd ${PYEDDL_SRC} && pytest tests'
        sh 'cd ${PYEDDL_SRC}/examples && python3 Tensor/eddl_tensor.py'
        sh 'cd ${PYEDDL_SRC}/examples && python3 NN/other/eddl_ae.py --epochs 1'
      }
    }

    stage('Test PyECVL') {
      agent {
        docker { image 'pylibs-toolkit:${DOCKER_IMAGE_TAG}' }
      }
      steps {
        sh 'cd ${PYECVL_SRC} && pytest tests'
        sh 'cd ${PYECVL_SRC}/examples && python3 dataset.py ${ECVL_SRC}/build/mnist/mnist.yml'
        sh 'cd ${PYECVL_SRC}/examples && python3 ecvl_eddl.py ${ECVL_SRC}/data/test.jpg ${ECVL_SRC}/build/mnist/mnist.yml'
        sh 'cd ${PYECVL_SRC}/examples && python3 img_format.py ${ECVL_SRC}/data/nifti/LR_nifti.nii ${ECVL_SRC}/data/isic_dicom/ISIC_0000008.dcm'
        sh 'cd ${PYECVL_SRC}/examples && python3 imgproc.py ${ECVL_SRC}/data/test.jpg'
        sh 'cd ${PYECVL_SRC}/examples && python3 openslide.py ${ECVL_SRC}/data/hamamatsu/10-B1-TALG.ndpi'
        sh 'cd ${PYECVL_SRC}/examples && python3 read_write.py ${ECVL_SRC}/data/test.jpg test_mod.jpg'
      }
    }

    stage('Publish Development Build') {
      when {
          not { branch "master" }
      }
      steps {
        script {
          docker.withRegistry( '', registryCredential ) {
            sh 'CONFIG_FILE="" DOCKER_IMAGE_TAG_EXTRA="" make push'
          }
        }
      }
    }

    stage('Publish Master Build') {
      environment {
        DOCKER_IMAGE_RELEASE_TAG = sh(returnStdout: true, script: "tag=\$(git tag -l --points-at HEAD); if [[ -n \${tag} ]]; then echo \${tag}; else git rev-parse --short HEAD --short; fi").trim()
        DOCKER_IMAGE_TAG_EXTRA = "${DOCKER_IMAGE_RELEASE_TAG} ${DOCKER_IMAGE_RELEASE_TAG}_${DOCKER_IMAGE_TAG}"
      }
      when {
          branch 'master'
      }
      steps {
        script {
          docker.withRegistry( '', registryCredential ) {
            sh 'echo DOCKER_IMAGE_RELEASE_TAG: ${DOCKER_IMAGE_RELEASE_TAG}'
            sh 'echo DOCKER_IMAGE_TAG_EXTRA: ${DOCKER_IMAGE_TAG_EXTRA}'
            sh 'make push'
          }
        }
      }
    }
  }

  post {
    always {
      echo 'One way or another, I have finished'
      deleteDir() /* clean up our workspace */
    }
    success {
      echo "Docker images successfully build and published with tags: ${DOCKER_IMAGE_TAG}"
      echo "Library revisions..."
      echo "* ECVL revision: ${ECVL_REVISION}"
      echo "* EDDL revision: ${EDDL_REVISION}"
      echo "* PyECVL revision: ${PYECVL_REVISION}"
      echo "* PyEDDL revision: ${PYEDDL_REVISION}"
    }
    unstable {
      echo 'I am unstable :/'
    }
    failure {
      echo 'I failed :('
    }
    changed {
      echo 'Things were different before...'
    }
  } 
}