// ================================================================
// Jenkins Pipeline for Next.js (App Router) — follows Express pattern
// - Checkout
// - Install & (conditionally) Test in Node Docker
// - Build & Push Docker image (production target)
// - Deploy to DEV on develop branch
// - Approval + Deploy to PROD on main branch
// - Rollback support
// - n8n webhook notifications
// Notes:
// - This Jenkinsfile lives in subfolder nextjs-docker-app, so we wrap
//   shell and docker build steps in dir('nextjs-docker-app') to target
//   the correct context.
// - The built container serves Next.js on port 3000 by default (next start).
// ================================================================

def sendNotificationToN8n(String status, String stageName, String imageTag, String containerName, String hostPort) {
	script {
		withCredentials([string(credentialsId: 'n8n-webhook', variable: 'N8N_WEBHOOK_URL')]) {
			def payload = [
				project  : env.JOB_NAME,
				stage    : stageName,
				status   : status,
				build    : env.BUILD_NUMBER,
				image    : "${env.DOCKER_REPO}:${imageTag}",
				container: containerName,
				url      : "http://localhost:${hostPort}/",
				timestamp: new Date().format("yyyy-MM-dd'T'HH:mm:ssXXX")
			]
			def body = groovy.json.JsonOutput.toJson(payload)
			try {
				httpRequest acceptType: 'APPLICATION_JSON',
							contentType: 'APPLICATION_JSON',
							httpMode: 'POST',
							requestBody: body,
							url: N8N_WEBHOOK_URL,
							validResponseCodes: '200:299'
				echo "n8n webhook (${status}) sent successfully."
			} catch (err) {
				echo "Failed to send n8n webhook (${status}): ${err}"
			}
		}
	}
}

pipeline {
	agent any

	options {
		skipDefaultCheckout(true)
	}

	environment {
		DOCKER_HUB_CREDENTIALS_ID = 'dockerhub-cred'
		DOCKER_REPO               = 'pannhapatmuac/nextjs-docker-app'
		DEV_APP_NAME              = 'nextjs-app-dev'
		DEV_HOST_PORT             = '4001'
		PROD_APP_NAME             = 'nextjs-app-prod'
		PROD_HOST_PORT            = '4000'
	}

	parameters {
		choice(name: 'ACTION', choices: ['Build & Deploy', 'Rollback'], description: 'เลือก Action ที่ต้องการ')
		string(name: 'ROLLBACK_TAG', defaultValue: '', description: 'สำหรับ Rollback: ใส่ Image Tag ที่ต้องการ (เช่น Git Hash หรือ dev-123)')
		choice(name: 'ROLLBACK_TARGET', choices: ['dev', 'prod'], description: 'สำหรับ Rollback: เลือกว่าจะ Rollback ที่ Environment ไหน')
	}

	stages {
		stage('Checkout') {
			when { expression { params.ACTION == 'Build & Deploy' } }
			steps {
				echo 'Checking out code...'
				checkout scm
			}
		}

	stage('Install & Test') {
		when { expression { params.ACTION == 'Build & Deploy' } }
		steps {
			echo 'Installing dependencies and running tests (if present) inside Node Docker...'
			script {
				docker.image('node:22-alpine').inside {
					sh '''
						set -eux
						if [ -f package-lock.json ]; then npm ci; else npm install; fi
						if node -e "const fs=require('fs'); try { const p=JSON.parse(fs.readFileSync('package.json','utf8')); process.exit(p.scripts && p.scripts.test ? 0 : 1); } catch (err) { process.exit(1); }"; then
							npm test
						else
							echo "No test script found. Running lint (non-blocking)."
							npm run -s lint || true
						fi
					'''
				}
			}
		}
	}

	stage('Build & Push Docker Image') {
		when { expression { params.ACTION == 'Build & Deploy' } }
		steps {
			script {
				def imageTag = (env.BRANCH_NAME == 'main') ? sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim() : "dev-${env.BUILD_NUMBER}"
				env.IMAGE_TAG = imageTag

				docker.withRegistry('https://index.docker.io/v1/', DOCKER_HUB_CREDENTIALS_ID) {
					echo "Building image: ${DOCKER_REPO}:${env.IMAGE_TAG}"
					
					def customImage = docker.build("${DOCKER_REPO}:${env.IMAGE_TAG}", "--target production .")
					
					echo 'Pushing images to Docker Hub...'
					customImage.push()
					if (env.BRANCH_NAME == 'main') {
						customImage.push('latest')
					}
				}
			}
		}
	}

		stage('Deploy to DEV (Local Docker)') {
		when { expression { params.ACTION == 'Build & Deploy' && env.BRANCH_NAME == 'develop' } }
		steps {
			script {
				def deployCmd = """
					echo "Deploying container ${DEV_APP_NAME}..."
					docker pull ${DOCKER_REPO}:${env.IMAGE_TAG}
					docker stop ${DEV_APP_NAME} || true
					docker rm ${DEV_APP_NAME} || true
					docker run -d --name ${DEV_APP_NAME} -p ${DEV_HOST_PORT}:3000 ${DOCKER_REPO}:${env.IMAGE_TAG}
				"""
				sh deployCmd
			}
		}
		post { success { sendNotificationToN8n('success', 'Deploy to DEV', env.IMAGE_TAG, env.DEV_APP_NAME, env.DEV_HOST_PORT) } }
	}

		stage('Approval for Production') {
		when { expression { params.ACTION == 'Build & Deploy' && env.BRANCH_NAME == 'main' } }
		steps {
			timeout(time: 1, unit: 'HOURS') {
				input message: "Deploy image tag '${env.IMAGE_TAG}' to PRODUCTION (Local Docker on port ${PROD_HOST_PORT})?"
			}
		}
	}

	stage('Deploy to PRODUCTION (Local Docker)') {
		when { expression { params.ACTION == 'Build & Deploy' && env.BRANCH_NAME == 'main' } }
		steps {
			script {
				def deployCmd = """
					echo "Deploying container ${PROD_APP_NAME}..."
					docker pull ${DOCKER_REPO}:${env.IMAGE_TAG}
					docker stop ${PROD_APP_NAME} || true
					docker rm ${PROD_APP_NAME} || true
					docker run -d --name ${PROD_APP_NAME} -p ${PROD_HOST_PORT}:3000 ${DOCKER_REPO}:${env.IMAGE_TAG}
				"""
				sh deployCmd
			}
		}
		post { success { sendNotificationToN8n('success', 'Deploy to PROD', env.IMAGE_TAG, env.PROD_APP_NAME, env.PROD_HOST_PORT) } }
	}

		stage('Execute Rollback') {
			when { expression { params.ACTION == 'Rollback' } }
			steps {
				script {
					if (params.ROLLBACK_TAG.trim().isEmpty()) {
						error "เมื่อเลือก Rollback กรุณาระบุ 'ROLLBACK_TAG'"
					}

					def targetAppName = (params.ROLLBACK_TARGET == 'dev') ? DEV_APP_NAME : PROD_APP_NAME
					def targetHostPort = (params.ROLLBACK_TARGET == 'dev') ? DEV_HOST_PORT : PROD_HOST_PORT
					def imageToDeploy = "${DOCKER_REPO}:${params.ROLLBACK_TAG.trim()}"

					// Save for post block
					env.ROLLBACK_APP_NAME = targetAppName
					env.ROLLBACK_HOST_PORT = targetHostPort

					echo "ROLLING BACK ${params.ROLLBACK_TARGET.toUpperCase()} to image: ${imageToDeploy}"
					sh """
						docker pull ${imageToDeploy}
						docker stop ${targetAppName} || true
						docker rm ${targetAppName} || true
						docker run -d --name ${targetAppName} -p ${targetHostPort}:3000 ${imageToDeploy}
					"""
				}
			}
			post {
				success {
					sendNotificationToN8n('success', "Rollback ${params.ROLLBACK_TARGET.toUpperCase()}", params.ROLLBACK_TAG, env.ROLLBACK_APP_NAME ?: 'N/A', env.ROLLBACK_HOST_PORT ?: 'N/A')
				}
			}
		}
	}

	post {
		always {
			script {
				if (params.ACTION == 'Build & Deploy' && env.IMAGE_TAG) {
					echo 'Cleaning up Docker images on agent...'
					try {
						sh """
							docker image rm -f ${DOCKER_REPO}:${env.IMAGE_TAG} || true
							docker image rm -f ${DOCKER_REPO}:latest || true
						"""
					} catch (err) {
						echo 'Could not clean up images, but continuing...'
					}
				}
			}
		}
		failure {
			sendNotificationToN8n('failed', 'Pipeline Failed', 'N/A', 'N/A', 'N/A')
		}
	}
}