// Jamii Savings Integration Platform: one pipeline for all three APIs (MI + APIM).
//
//  Checkout -> Prepare -> Validate -> Unit tests -> Build images -> Package APIM
//  -> Deploy dev (MI + APIM, all or nothing) -> Test dev -> [approval] Promote to prod (dry run)
//
// Every image of a release carries the same tag (the build number), so a release is one set of
// images. On failure after deployment started, the pipeline rolls the dev stack back to the last
// release that passed, including the API definitions (re-imported by that release's apim-init).

def APIS = ['JamiiAccountBalance', 'JamiiCustomerProfile', 'JamiiLoanEligibility']   // one loop, no copy-paste
def LAST_GOOD_FILE = '/var/jenkins_home/jamii-last-good-tag'

pipeline {
  agent any
  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timeout(time: 60, unit: 'MINUTES')
  }
  parameters {
    booleanParam(name: 'PROMOTE_TO_PROD', defaultValue: false, description: 'Run the approval-gated prod stage (dry run)')
    booleanParam(name: 'FORCE_FAIL_IMPORT', defaultValue: false, description: 'Demo: break one API import to prove there is no partial deploy and rollback runs')
    booleanParam(name: 'NO_CACHE', defaultValue: false, description: 'Build every image from scratch (docker build --no-cache)')
  }
  environment {
    COMPOSE              = 'docker compose -f docker-compose.yml -f docker-compose.ci.yml'   // used as $COMPOSE in sh steps
    COMPOSE_PROJECT_NAME = 'jamii'
    COMPOSE_PROFILES     = 'core'
    TAG                  = "${env.BUILD_NUMBER}"
    REGISTRY             = 'localhost:5000'
    MI_VERSION           = '4.3.0'
    APIM_VERSION         = '4.4.0'
    WSO2_JAVA_BASE_IMAGE = 'eclipse-temurin:17-jre'
    JAVA_BASE_IMAGE      = 'eclipse-temurin:21-jre'
    H2_DB_NAME           = 'jamii'
    H2_USER              = 'jamii_app'
    H2_RESET_ON_START    = 'true'
    APIM_ADMIN_USER      = 'admin'
    CUSTOMER_BACKEND_URL = 'http://jamii-mock-backends:8080'
    CREDIT_BACKEND_URL   = 'http://jamii-mock-backends:8080/ws'
    ELASTIC_VERSION      = '8.15.0'
    RUN_GATEWAY_CHECK    = 'false'
    APIM_ADMIN_PASSWORD  = credentials('apim-admin-password')
    H2_PASSWORD          = credentials('h2-password')
  }

  stages {
    stage('Prepare') {
      steps {
        sh '''
          set -e
          mkdir -p dist reports
          cp /dist/*.zip /dist/checksums.txt dist/
          docker version --format 'Docker {{.Server.Version}}'
          docker compose version
          echo "Release tag: $TAG"
        '''
        script { env.NO_CACHE_FLAG = params.NO_CACHE ? '--no-cache' : ''; echo "Image builds: ${params.NO_CACHE ? 'no cache' : 'cached layers allowed'}" }
        script {
          if (params.FORCE_FAIL_IMPORT) {
            echo 'FORCE_FAIL_IMPORT: pointing JamiiLoanEligibility at a tier that does not exist'
            sh "sed -i 's/LoanCheck10PerMin/NoSuchTier/' apim/apis/JamiiLoanEligibility-v1/api.yaml"
          }
        }
      }
    }

    stage('Validate') {
      // Everything is validated before anything is deployed.
      steps {
        sh '''
          set -e
          echo "== MI artifacts are well-formed XML"
          find mi/src -name '*.xml' -o -name '*.dbs' | xargs -n1 xmllint --noout
          echo "== shell scripts"
          for f in scripts/*.sh docker/*/*.sh; do bash -n "$f"; done
          echo "== compose files"
          $COMPOSE config -q
        '''
        script {
          for (api in APIS) {
            sh """
              set -e
              echo "== ${api}: OpenAPI spec and apictl project"
              python3 -c "import yaml; from openapi_spec_validator import validate; validate(yaml.safe_load(open('apim/apis/${api}-v1/Definitions/swagger.yaml')))"
              test -f apim/apis/${api}-v1/api.yaml
              test -f apim/params/dev/${api}.yaml && test -f apim/params/prod/${api}.yaml
            """
          }
        }
      }
    }

    stage('Unit tests') {
      steps {
        sh '''
          set -e
          docker build $NO_CACHE_FLAG --target build -t jamii/mock-backends-build:$TAG mock-backends
          id=$(docker create jamii/mock-backends-build:$TAG)
          docker cp "$id:/src/target/surefire-reports" reports/mock-backends
          docker rm "$id" >/dev/null
        '''
      }
      post { always { junit allowEmptyResults: true, testResults: 'reports/mock-backends/*.xml' } }
    }

    stage('Build images') {
      steps {
        sh '$COMPOSE build $NO_CACHE_FLAG mock-backends h2 mi apim apim-init'
        sh 'docker image ls --format "{{.Repository}}:{{.Tag}}  {{.Size}}" | grep "jamii/.*:$TAG"'
      }
    }

    stage('Package APIM') {
      steps {
        sh 'tar czf jamii-apim-$TAG.tgz apim/'
        archiveArtifacts artifacts: "jamii-apim-${env.TAG}.tgz", fingerprint: true
      }
    }

    stage('Deploy dev') {
      // MI and APIM move together: if publishing fails, post { failure } rolls everything back.
      steps {
        sh '''
          set -e
          echo "== MI, its backends and API Manager (release $TAG)"
          $COMPOSE up -d --no-build --wait mock-backends h2 mi apim
          echo "== publish: tier, APIs, API Product, demo apps"
          $COMPOSE run --rm apim-init
        '''
      }
    }

    stage('Test dev') {
      steps {
        sh '''
          set -e
          echo "== MI direct (19 checks, inside the Docker network)"
          $COMPOSE run --rm --no-deps --entrypoint bash apim-init -c "bash scripts/mi-smoke.sh http://mi:8290 --with-slow"
          echo "== Gateway (14 checks)"
          $COMPOSE run --rm --no-deps --entrypoint bash apim-init -c \
            "GATEWAY_URL_OVERRIDE=https://apim:8243 TOKEN_URL_OVERRIDE=https://apim:9443/oauth2/token bash scripts/gateway-check.sh"
          echo "== Masking: no full account numbers or customer PII in MI logs"
          if docker compose logs mi | grep -E "0123456789|Wanjiru|28456123"; then echo "PII found in MI logs"; exit 1; fi
          echo "no PII in MI logs"
        '''
      }
    }

    stage('Promote to prod (dry run)') {
      when { expression { params.PROMOTE_TO_PROD } }
      steps {
        input message: "Promote release ${env.TAG} to prod?", ok: 'Promote'
        script {
          for (api in APIS) {
            sh """
              echo "DRY RUN  apictl import api -f apim/apis/${api}-v1 -e prod --params apim/params/prod/${api}.yaml --update --rotate-revision"
            """
          }
        }
        echo 'DRY RUN  push images tagged ' + env.TAG + ' to the production registry, then deploy MI before APIM'
      }
    }
  }

  post {
    success {
      sh "echo $TAG > ${LAST_GOOD_FILE}"
      echo "Release ${env.TAG} is now the last good release"
    }
    failure {
      script {
        def last = sh(script: "cat ${LAST_GOOD_FILE} 2>/dev/null || true", returnStdout: true).trim()
        if (last && last != env.TAG) {
          echo "ROLLBACK: restoring release ${last} (images and API definitions)"
          withEnv(["TAG=${last}"]) {
            sh '$COMPOSE up -d --no-build --wait mock-backends h2 mi apim'
            sh '$COMPOSE run --rm apim-init'
          }
        } else {
          echo 'No earlier good release recorded; nothing to roll back to.'
        }
      }
    }
    always {
      sh 'docker compose logs --no-color mi apim > reports/stack.log 2>&1 || true'
      archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
    }
  }
}