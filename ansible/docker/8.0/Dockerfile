# Using the CENTOS container from the docker library
FROM centos:latest

# Install latest updates from repo
RUN dnf update -y

# Requirements for Ansible and the ucs sdks
RUN dnf install epel-release python3 python3-pip git vim -y && \
pip3 install --upgrade pip

# Install the Ansible and UCS compenents.
RUN pip install ucsmsdk imcsdk xmljson lxml ansible


