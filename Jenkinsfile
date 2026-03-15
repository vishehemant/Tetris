pipeline {
    agent any

    environment {
        DOCKER_HUB_CREDENTIALS = credentials('dockerhub-credentials')
        DOCKER_IMAGE           = "YOUR_DOCKERHUB_USERNAME/tetris-app"
        SONARQUBE_URL          = "http://sonarqube:9000"
        GIT_REPO               = "https://github.com/YOUR_GITHUB_USERNAME/tetris-devsecops.git"
        SCANNER_HOME           = tool('sonar-scanner')
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
    }

    stages {
        stage('Checkout') {
            steps {
                cleanWs()
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.BUILD_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonarqube-server') {
                    sh """
                        ${SCANNER_HOME}/bin/sonar-scanner \
                            -Dsonar.projectKey=tetris-app \
                            -Dsonar.projectName='Tetris App' \
                            -Dsonar.projectVersion=${env.BUILD_TAG} \
                            -Dsonar.sources=app/ \
                            -Dsonar.sourceEncoding=UTF-8
                    """
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Docker Build') {
            steps {
                script {
                    dockerImage = docker.build("${DOCKER_IMAGE}:${env.BUILD_TAG}")
                    docker.build("${DOCKER_IMAGE}:latest")
                }
            }
        }

        stage('Trivy - Image Vulnerability Scan') {
            steps {
                sh """
                    trivy image \
                        --severity HIGH,CRITICAL \
                        --format table \
                        --output trivy-image-report.txt \
                        ${DOCKER_IMAGE}:${env.BUILD_TAG}
                """

                sh """
                    trivy image \
                        --severity HIGH,CRITICAL \
                        --format json \
                        --output trivy-image-report.json \
                        ${DOCKER_IMAGE}:${env.BUILD_TAG}
                """

                publishHTML(target: [
                    reportDir: '.',
                    reportFiles: 'trivy-image-report.txt',
                    reportName: 'Trivy Image Scan Report'
                ])
            }
        }

        stage('Trivy - Filesystem Scan') {
            steps {
                sh """
                    trivy fs \
                        --severity HIGH,CRITICAL \
                        --format table \
                        --output trivy-fs-report.txt \
                        .
                """
                publishHTML(target: [
                    reportDir: '.',
                    reportFiles: 'trivy-fs-report.txt',
                    reportName: 'Trivy Filesystem Scan Report'
                ])
            }
        }

        stage('Trivy - Dockerfile Scan') {
            steps {
                sh """
                    trivy config \
                        --severity HIGH,CRITICAL \
                        --format table \
                        --output trivy-config-report.txt \
                        Dockerfile
                """
            }
        }

        stage('Docker Push') {
            steps {
                script {
                    docker.withRegistry('https://registry.hub.docker.com', 'dockerhub-credentials') {
                        dockerImage.push("${env.BUILD_TAG}")
                        dockerImage.push("latest")
                    }
                }
            }
        }

        stage('Update Kubernetes Manifests') {
            steps {
                script {
                    sh """
                        sed -i 's|image: .*|image: ${DOCKER_IMAGE}:${env.BUILD_TAG}|' k8s/deployment.yaml
                    """
                }
                withCredentials([gitUsernamePassword(credentialsId: 'github-credentials')]) {
                    sh """
                        git config user.email "jenkins@devsecops.local"
                        git config user.name "Jenkins CI"
                        git add k8s/deployment.yaml
                        git commit -m "ci: update image tag to ${env.BUILD_TAG}" || true
                        git push origin HEAD:main
                    """
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'trivy-*.txt,trivy-*.json', fingerprint: true, allowEmptyArchive: true
            cleanWs()
        }
        success {
            echo "Pipeline completed successfully! Image: ${DOCKER_IMAGE}:${env.BUILD_TAG}"
            slackSend(
                channel: '#devsecops',
                color: 'good',
                message: "SUCCESS: Tetris pipeline #${env.BUILD_NUMBER} - Image: ${DOCKER_IMAGE}:${env.BUILD_TAG}"
            )
        }
        failure {
            echo "Pipeline failed!"
            slackSend(
                channel: '#devsecops',
                color: 'danger',
                message: "FAILURE: Tetris pipeline #${env.BUILD_NUMBER} - Check Jenkins for details"
            )
        }
    }
}
