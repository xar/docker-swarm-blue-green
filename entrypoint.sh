#!/bin/sh
set -eu

if [ -z "$INPUT_REMOTE_HOST" ]; then
    echo "Input remote_host is required!"
    exit 1
fi

# Extra handling for SSH-based connections.
if [ ${INPUT_REMOTE_HOST#"ssh://"} != "$INPUT_REMOTE_HOST" ]; then
    SSH_HOST=${INPUT_REMOTE_HOST#"ssh://"}
    SSH_HOST=${SSH_HOST#*@}

    if [ -z "$INPUT_SSH_PRIVATE_KEY" ]; then
        echo "Input ssh_private_key is required for SSH hosts!"
        exit 1
    fi

    if [ -z "$INPUT_SSH_PUBLIC_KEY" ]; then
        echo "Input ssh_public_key is required for SSH hosts!"
        exit 1
    fi

docker login -u oauth2accesstoken --password $ACCESS_TOKEN $INPUT_DOCKER_REGISTRY


    if [ -z "$ACCESS_TOKEN" ]; then
        docker login -u oauth2accesstoken --password $ACCESS_TOKEN $INPUT_DOCKER_REGISTRY
    fi

    echo "Registering SSH keys..."

    # Save private key to a file and register it with the agent.
    mkdir -p "$HOME/.ssh"
    printf '%s' "$INPUT_SSH_PRIVATE_KEY" > "$HOME/.ssh/docker"
    chmod 600 "$HOME/.ssh/docker"
    eval $(ssh-agent)
    ssh-add "$HOME/.ssh/docker"
    
    # Add public key to known hosts.
    echo "Add public key verify..."
    printf '%s %s\n' "$SSH_HOST" "$INPUT_SSH_PUBLIC_KEY" >> /etc/ssh/ssh_known_hosts
    
    echo "Cat known hosts"
    cat /etc/ssh/ssh_known_hosts
    
    echo "
    Host *
       StrictHostKeyChecking no
    " >> "$HOME/.ssh/config"
    
    echo "Chmod 400 config"
    chmod 400 "$HOME/.ssh/config"
    
    echo $INPUT_REMOTE_HOST
    ssh -o StrictHostKeyChecking=no -T deploy@195.201.47.156 -p 222
fi

echo "Connecting to $INPUT_REMOTE_HOST..."


if [ $(docker --host "$INPUT_REMOTE_HOST" ps -f name=$INPUT_BLUE_NAME -q) ]
then
    ENV=$INPUT_GREEN_NAME
    OLD=$INPUT_BLUE_NAME
else
    ENV=$INPUT_BLUE_NAME
    OLD=$INPUT_GREEN_NAME
fi

echo "Starting "$ENV" container"
docker --log-level debug --host "$INPUT_REMOTE_HOST" "$@" $ENV 2>&1

echo "Waiting..."
sleep 5s

echo "Stopping "$OLD" container"
docker --log-level debug --host "$INPUT_REMOTE_HOST" stack rm $OLD
echo "OK!"
