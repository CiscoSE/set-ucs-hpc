# Using the CENTOS container from the docker library
FROM centos:8

# Requirements for Ansible and the ucs sdks
RUN yum install epel-release python3 python3-pip -y

# Common tools. You can delete these if you like
RUN yum install screen vim git -y

# Install the ucsmsdk using the 2.7 version of pip.
RUN pip3 install ucsmsdk

#Install imcsdk using the 3.0 version of pip.
RUN pip3 install imcsdk

#Install Ansible with pip3 so we get ansible fully compatible with python 3.6
RUN pip3 install ansible

