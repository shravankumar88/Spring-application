pipeline{
	agent any
		options {
        office365ConnectorWebhooks([[
                    startNotification: true,
                    notifyAborted: true, 
					notifyBackToNormal: true, 
					notifyFailure: true, 
					notifyNotBuilt: true, 
					notifyRepeatedFailure: true, 
					notifySuccess: true, 
					notifyUnstable: true, 
					url: 'https://dell.webhook.office.com/webhookb2/e19e7620-1016-4e14-9946-77b8c138c497@945c199a-83a2-4e80-9f8c-5a91be5752dd/IncomingWebhook/942a5149d27546b7876d2766d75f3b97/88033528-8d47-4bef-9143-9763bd233599'
    	        ]]
       		)
    	}
	environment{
		BUILD_VERSION="${env.BUILD_ID}"
		JOB_NAME="${env.JOB_NAME}"
		BUILD_NUMBER="${env.BUILD_NUMBER}"
		POM_VERSION = readMavenPom().getVersion()
		}
	stages{
	    // stage("checkout respository"){
	    //     steps{
	    //         cleanWs(patterns: [[pattern: '', type: 'INCLUDE']])
	    //     }
	    // }
	    // stage("checkout "){
        // 	        steps{
        // 	             bbs_checkout branches: [[name: '*/master']], credentialsId: 'jenkinsAuth-BitBucket', id: 'ef303c8b-16bd-4c3c-8902-c6062d1be207', projectName: '~SHRAVAN.THAMATAM', repositoryName: 'spring-application', serverId: 'b966ce85-9ef6-4ad1-a62d-d5f22fdb40e6'
        // 	        }
        // }
		stage('MVN Package'){
			steps{
				echo "POM_VERSION=${POM_VERSION}"

			}
		}
		// stage("Code coverage") {
        //     steps {
        //         jacoco(
        //             execPattern: '**/target/**.exec',
        //             classPattern: '**/target/classes',
        //             sourcePattern: '**/src',
        //             inclusionPattern: 'com/dell/**',
        //             changeBuildStatus: true,
        //             minimumInstructionCoverage: '0',
        //             maximumInstructionCoverage: '0')
        //     }
        // }
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
						docker build -t $jfrog_url/code-docker/${JOB_NAME}:${BUILD_VERSION}.${POM_VERSION} .
						docker login -u $docker_username -p $docker_password $jfrog_url
						docker push $jfrog_url/code-docker/${JOB_NAME}:${BUILD_VERSION}.${POM_VERSION}
						docker rmi $jfrog_url/code-docker/${JOB_NAME}:${BUILD_VERSION}.${POM_VERSION}				
						'''
					}
				}
			}
		}
		stage("trivy scan"){
        			steps{
        				script{
        					withCredentials([
        					string(credentialsId:'jfrog_url',variable:'jfrog_url')])
        					{
        					sh'''
        					trivy image --severity HIGH,CRITICAL $jfrog_url/code-docker/${JOB_NAME}:${BUILD_VERSION}.${POM_VERSION}
        					trivy image -f json -o results.json $jfrog_url/code-docker/${JOB_NAME}:${BUILD_VERSION}.${POM_VERSION}
        					trivy image --exit-code 0 --severity MEDIUM,LOW $jfrog_url/code-docker/${JOB_NAME}:${BUILD_VERSION}.${POM_VERSION}
        					trivy image --exit-code 1 --severity CRITICAL,HIGH $jfrog_url/code-docker/${JOB_NAME}:${BUILD_VERSION}.${POM_VERSION}
        					'''
        					}
        				}

        			}
        		}
		// 	stage("indentifying misconfig using datree in helm charts"){
		//  		steps{
	 	// 		dir('kubernetes/') {
		// 				withEnv(['DATREE_TOKEN=2EuQb88b8TtxuAikuZhCT8']) {
		// 					}
		// 					sh '''
		//                     //helm plugin install https://github.com/datreeio/helm-datree
		//                     helm datree test myapp/
		//                     '''
		//  				}
	
		//  	}
		//  }
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
		stage('Deploy the application') {
            steps {
                script{
                    withCredentials([
						string(credentialsId:'jfrog_url',variable:'jfrog_url'),
						kubeconfigFile(credentialsId: 'kuberntes-config', variable: 'KUBECONFIG')]) {
							dir('kubernetes/'){
                         sh 'helm upgrade --install --set image.repository="$jfrog_url/code-docker/${JOB_NAME}" --set image.tag="${BUILD_VERSION}.${POM_VERSION}" myjavapp myapp/ '
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
					sh 'curl 20.127.64.133:31917'
					}
				}
			}
		}
	}
}
