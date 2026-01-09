#!/bin/bash

apt-get install wget apt-transport-https gnupg
wget -qO - https://get.trivy.dev/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://get.trivy.dev/deb generic main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
apt-get update
apt-get install trivy
