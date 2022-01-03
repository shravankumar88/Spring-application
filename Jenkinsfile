pipeline{
	agent any
		
	environment{
		BUILD_VERSION="${env.BUILD_ID}"
		JOB_NAME="${env.JOB_NAME}"
		BUILD_NUMBER="${env.BUILD_NUMBER}"
		POM_VERSION=
		}
	stages{
	    stage("checkout respository"){
	        steps{
	            cleanWs(patterns: [[pattern: '', type: 'INCLUDE']])
	        }
	    }
		stage('MVN Package'){
			steps{
				sh "mvn clean install"

			}
		}
		stage("Code coverage") {
            steps {
                jacoco(
                    execPattern: '**/target/**.exec',
                    classPattern: '**/target/classes',
                    sourcePattern: '**/src',
                    inclusionPattern: 'com/dell/**',
                    changeBuildStatus: true,
                    minimumInstructionCoverage: '0',
                    maximumInstructionCoverage: '0')
            }
        }

        stage('QualityGateStatusCheck'){
		agent{
			docker{
				image'maven'
				args'-v$HOME/.m2:/root/.m2'
				}
			}
			steps{
				script{
					withSonarQubeEnv('sonarqube')
					{
						sh"mvn clean verify sonar:sonar -Dsonar.projectKey=com.dell:spring-application"
					}
						timeout(time:1,unit:'MINUTES'){
						sleep 30
						def qg=waitForQualityGate()
						if (qg.status != 'OK'){
						error"Pipelineabortedduetoqualitygatefailure:${qg.status}"
						}
					}
				}
			}
		}
		stage("dockerbuild&dockerpush"){
			steps{
				script{
					withCredentials([
					string(credentialsId:'jfrog_url',variable:'jfrog_url'),
					string(credentialsId:'docker_un',variable:'docker_username'),
					string(credentialsId:'docker_pass',variable:'docker_password')])
						{
						sh'''
						docker build -t $jfrog_url/code-docker/${JOB_NAME}:${BUILD_VERSION} .
						docker login -u $docker_username -p $docker_password $jfrog_url
						docker push $jfrog_url/code-docker/${JOB_NAME}:${BUILD_VERSION}
						docker rmi $jfrog_url/code-docker/${JOB_NAME}:${BUILD_VERSION}
						'''
					}
				}
			}
		}
		stage("image scan"){
        			steps{
        				script{
        					withCredentials([
        					string(credentialsId:'jfrog_url',variable:'jfrog_url')])
        					{
        					sh'''
        					trivy image --severity HIGH,CRITICAL $jfrog_url/code-docker/${JOB_NAME}:${BUILD_VERSION}
        					trivy image -f json -o results.json $jfrog_url/code-docker/${JOB_NAME}:${BUILD_VERSION}
        					trivy image --exit-code 0 --severity MEDIUM,LOW $jfrog_url/code-docker/${JOB_NAME}:${BUILD_VERSION}
        					trivy image --exit-code 1 --severity CRITICAL,HIGH $jfrog_url/code-docker/${JOB_NAME}:${BUILD_VERSION}
        					'''
        					}
        				}

        			}
        		}
			stage("indentifying misconfig using datree in helm charts"){
		 		steps{
	 			dir('kubernetes/') {
						withEnv(['DATREE_TOKEN=2EuQb88b8TtxuAikuZhCT8']) {
							}
							sh '''
		                    helm plugin install https://github.com/datreeio/helm-datree
		                    helm datree test myapp/
		                    '''
		 				}
	
		 	}
		 }
		stage("push helm charts"){
			steps{
				script{
					withCredentials([
					string(credentialsId:'jfrog_url',variable:'jfrog_url'),
					string(credentialsId:'docker_un',variable:'docker_username'),
					string(credentialsId:'docker_pass',variable:'docker_password')]){
						dir('kubernetes/'){
						sh'''
						helmversion=$(helm show chart myapp |  grep version | cut -d: -f 2 | tr -d ' ')
						tar -czvf myapp-${helmversion}.tgz myapp/
						curl -u$docker_un:$docker_pass -T myapp-${helmversion}.tgz "$jfrog_url/artifactorycode-helm/" --upload-file myapp-${helmversion}.tgz -v
						'''
						}
						//helm repo add myapp-${helmversion}.tgz $jfrog_url/artifactory/api/helm/code-helm --username $docker_username --password $docker_password
					}
				}
			}
		}
		stage("approval"){
			steps{	
				script{		
				withCredentials([
					string(credentialsId:'webhook_url',variable:'webhook_url')]){
					office365ConnectorSend message: 'office365ConnectorSend message:"started ${env.JOB_NAME} ${env.BUILD_NUMBER} (<${env.BUILD_URL}|Open>)"', 
					status: 'Approval', 
					webhookUrl: '$webhook_url'
					input(id: "Deploy Gate", message: "Deploy ${params.project_name}?", ok: 'Deploy')
					}
				}
			}
		}
		stage('Deploy the application') {
            steps {
                script{
                    withCredentials([
						string(credentialsId:'jfrog_url',variable:'jfrog_url'),
						kubeconfigFile(credentialsId: 'kuberntes-config', variable: 'KUBECONFIG')]) {
							dir('kubernetes/'){
                         sh 'helm upgrade --install --set image.repository="$jfrog_url/code-docker/${JOB_NAME}" --set image.tag="${BUILD_VERSION}" myjavapp myapp/ '
						}
                    }
                }
            }
        }
		stage("verifying app deployment"){
			steps{
				script{
					withCredentials([
					kubeconfigFile(credentialsId: 'kuberntes-config', variable: 'KUBECONFIG')]) {
					sh 'curl http://20.124.100.59:32732/'
					}
				}
			}
		}
	}
}
