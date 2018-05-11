variables:
  PROJECT_LANGUAGE: "python:3.6"
  DOCKER_REGISTRY_URL: "registry.hexcloud.cn"
  # rancher server API endpoint
  # must with http scheme
  RANCHER_ENDPOINT_URL: "http://rancher.hexcloud.cn/v2-beta"

stages:
  - build
  - test
  - staging
  - deploy

before_script:
  - 'echo "PROJECT NAME : $CI_PROJECT_NAME"'
  - 'echo "PROJECT ID : $CI_PROJECT_ID"'
  - 'echo "PROJECT URL : $CI_PROJECT_URL"'
  - 'echo "ENVIRONMENT URL : $CI_ENVIRONMENT_URL"'
  - 'echo "DOCKER REGISTRY URL : $DOCKER_REGISTRY_URL"'
  - 'export PATH=$PATH:/usr/bin'

# after_script:

build_image:
  stage: build
  only:
    - master
    - develop
    - staging
  when: manual
  allow_failure: false
  script:
    - 'echo "Job $CI_JOB_NAME triggered by $GITLAB_USER_NAME ($GITLAB_USER_ID)"'
    - 'echo "Build on $CI_COMMIT_REF_NAME"'
    - 'echo "HEAD commit SHA $CI_COMMIT_SHA"'
    # docker repo name must be lowercase
    - 'PROJECT_NAME_LOWERCASE=$(tr "[:upper:]" "[:lower:]" <<< $CI_PROJECT_NAME)'
    - 'IMAGE_REPO=$DOCKER_REGISTRY_URL/$PROJECT_NAME_LOWERCASE/$CI_COMMIT_REF_NAME'
    - 'IMAGE_TAG=$IMAGE_REPO:$CI_COMMIT_SHA'
    - 'IMAGE_TAG_LATEST=$IMAGE_REPO:latest'
    - 'docker build -t $IMAGE_TAG -t $IMAGE_TAG_LATEST .'
    - 'OLD_IMAGE_ID=$(docker images --filter="before=$IMAGE_TAG" $IMAGE_REPO -q)'
    - '[[ -z $OLD_IMAGE_ID ]] || docker rmi -f $OLD_IMAGE_ID'
    - 'docker push $IMAGE_TAG'
    - 'docker push $IMAGE_TAG_LATEST'

deploy_test:
  stage: test
  only:
    - develop
  when: manual
  environment:
    name: test
  variables:
    CI_RANCHER_ACCESS_KEY: $CI_RANCHER_ACCESS_KEY_TEST
    CI_RANCHER_SECRET_KEY: $CI_RANCHER_SECRET_KEY_TEST
    CI_RANCHER_STACK: $CI_RANCHER_STACK
    CI_RANCHER_SERVICE: $CI_RANCHER_SERVICE
    CI_RANCHER_ENV: $CI_RANCHER_ENV_TEST
  script:
    - 'echo "Deploy for test"'
    # WARNING: docker container ceres running on gitlab server for shell executor
    # TODO: change to docker executor
    - 'docker exec ceres ceres rancher_deploy --rancher-url=$RANCHER_ENDPOINT_URL --rancher-key=$CI_RANCHER_ACCESS_KEY --rancher-secret=$CI_RANCHER_SECRET_KEY --service=$CI_RANCHER_SERVICE --stack=$CI_RANCHER_STACK --rancher-env=$CI_RANCHER_ENV'

deploy_validate:
  stage: staging
  only:
    - staging
  when: manual
  environment:
    name: staging
  variables:
    CI_RANCHER_ACCESS_KEY: $CI_RANCHER_ACCESS_KEY_TEST
    CI_RANCHER_SECRET_KEY: $CI_RANCHER_SECRET_KEY_TEST
    CI_RANCHER_STACK: $CI_RANCHER_STACK
    CI_RANCHER_SERVICE: $CI_RANCHER_SERVICE
    CI_RANCHER_ENV: $CI_RANCHER_ENV_STAGING
  script:
    - echo "Deploy for validation"
    # WARNING: docker container ceres running on gitlab server for shell executor
    # TODO: change to docker executor
    - 'docker exec ceres ceres rancher_deploy --rancher-url=$RANCHER_ENDPOINT_URL --rancher-key=$CI_RANCHER_ACCESS_KEY --rancher-secret=$CI_RANCHER_SECRET_KEY --service=$CI_RANCHER_SERVICE --stack=$CI_RANCHER_STACK --rancher-env=$CI_RANCHER_ENV'

deploy_production:
  stage: deploy
  only:
    - master
  when: manual
  environment:
    name: production
  variables:
    CI_RANCHER_ACCESS_KEY: $CI_RANCHER_ACCESS_KEY_TEST
    CI_RANCHER_SECRET_KEY: $CI_RANCHER_SECRET_KEY_TEST
    CI_RANCHER_STACK: $CI_RANCHER_STACK
    CI_RANCHER_SERVICE: $CI_RANCHER_SERVICE
    CI_RANCHER_ENV: $CI_RANCHER_ENV_PROD
  script:
    - echo "Deploy for production"
    # WARNING: docker container ceres running on gitlab server for shell executor
    # TODO: change to docker executor
    - 'docker exec ceres ceres rancher_deploy --rancher-url=$RANCHER_ENDPOINT_URL --rancher-key=$CI_RANCHER_ACCESS_KEY --rancher-secret=$CI_RANCHER_SECRET_KEY --service=$CI_RANCHER_SERVICE --stack=$CI_RANCHER_STACK --rancher-env=$CI_RANCHER_ENV'

