// Single pipeline for all three APIs (balance, customer, loan).
// Stage bodies are filled in under Jira epic E10; this skeleton fixes the shape.
pipeline {
  agent any
  options { timestamps(); disableConcurrentBuilds() }
  parameters {
    booleanParam(name: 'PROMOTE_TO_PROD', defaultValue: false, description: 'Run the gated prod stage (dry run)')
  }
  environment {
    APIS     = 'balance customer loan'
    TAG      = "${env.BUILD_NUMBER}"
    REGISTRY = 'localhost:5000'
  }
  stages {
    stage('Checkout')      { steps { checkout scm } }
    stage('Validate')      { steps { sh 'echo "TODO S10.3: xmllint, OAS lint, apictl params check"' } }
    stage('Build MI')      { steps { sh 'echo "TODO S10.3: mvn clean install (MI unit tests), build and push images"' } }
    stage('Package APIM')  { steps { sh 'echo "TODO S10.4: package apictl projects for ${APIS} and the API Product"' } }
    stage('Deploy dev')    { steps { sh 'echo "TODO S10.5: save rollback point, swap MI image, apictl import loop (set -e)"' } }
    stage('Test dev')      { steps { sh 'echo "TODO S10.6: scripts/gateway-check.sh and masked-log grep"' } }
    stage('Deploy prod') {
      when { expression { params.PROMOTE_TO_PROD } }
      steps {
        input message: 'Promote this build to prod?'
        sh 'echo "TODO S10.8: apictl import to env prod (dry run), same artifacts"'
      }
    }
  }
  post {
    failure { sh 'echo "TODO S10.7: scripts/rollback.sh"' }
  }
}
