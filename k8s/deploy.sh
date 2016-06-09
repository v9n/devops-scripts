#!/bin/bash

set -e

# Those should be JENKINS vars
NAME=nginx-deployment-3
PODS_COUNT=3
CONTAINER_NAME=nginx
DOCKER_IMAGE='nginx:1.8'
# Template can be copied from deploy.tmp.yaml to update jenkins var
TEMPLATE=$(cat deploy.tmpl.yaml)
# path to kubectl
kubectl="/usr/local/bin/kubectl --namespace nginx"
# Stop editing

# Generate template
generate()
{
  # Using sed to replace vari
  echo -e "$TEMPLATE"
  echo -e "$TEMPLATE" | \
    sed "s/__NAME__/$NAME/g" | \
    sed "s/__REPLICA__/$PODS_COUNT/g" | \
    sed "s/__CONTAINER_NAME__/$CONTAINER_NAME/g" | \
    sed "s/__IMAGE__/$DOCKER_IMAGE/g" \
    > deploy.spec.yaml
  cat deploy.spec.yaml
  echo -e "\n\n"
}

deployment_exist()
{
  $kubectl get deployments | grep -q $NAME
  local rc="$?"
  return "$rc"
}

rollback()
{
  echo 'Starting rollback'
  echo $kubectl rollout undo deployment/$NAME
  $kubectl rollout undo deployment/$NAME
  if poll_status_ok; then
    echo "Rollback succeed"
    return 0
  else
    echo "Fail to rollback. Please rollback manually"
    return 1
  fi
}

poll_status_ok()
{
  local gencount=1
  local obscount=0

  echo "Polling status of deployment"
  while [ "$obscount" -lt "$gencount" ]; do
    local generation=`$kubectl get deployment/$NAME -o yaml | grep '[Gg]eneration'`
    gencount=$(echo -e "$generation" | head  -n1 | awk -F': ' '{print $2}')
    obscount=$(echo -e "$generation" | tail  -n1 | awk -F': ' '{print $2}')
    echo "Found generation: $gencount"
    echo "Found observedGeneration: $obscount"
    sleep 5
  done

  local uptodate_count=$($kubectl get deployments | grep $NAME | awk '{print $4}')
  if [ "$uptodate_count" -ge "$PODS_COUNT" ]; then
    return 0
  fi
  return 1
}

main()
{
  # First, generate yaml file form template and vars
  generate

  # We have different flow for existing and fresh new deployment
  if deployment_exist; then
    echo "Update existing deployment"
    echo $kubectl apply  -f deploy.spec.yaml
    $kubectl apply  -f deploy.spec.yaml

    if poll_status_ok; then
      echo "Deployment is updated"
    else
      echo "Fail to update existing deployment. We will rollback"
      rollback
      exit 1
    fi
  else
    echo "Create first deployment"
    echo $kubectl create -f deploy.spec.yaml
    $kubectl create -f deploy.spec.yaml

    if poll_status_ok; then
      echo "Deployment is create"
    else
      echo "Deployment is failed to create. Exit"
      exit 1
    fi
  fi

  return 0
}

main
exit 0
