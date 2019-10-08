# Using the CENTOS container from the docker library
FROM centos:7.6.1810
# Want the image completely patched. Have not tested without this.
RUN yum update -y

# Common tools. you can delete this line or modify it as you like... 
RUN yum install epel-release vim screen git -y

# Install and patch pip for 2.7, which is is required for the UCSM SDK.  
# I have had problems if I don't fully patch up pip.
RUN yum install python-pip -y
RUN pip install --upgrade pip

##########################################################
# I have not been able to install the sdks with 3.6
# Use pip for 2.7 until we get that sorted out.
##########################################################

# Install the ucsmsdk using the 2.7 version of pip.
RUN pip install ucsmsdk

#Install imcsdk using the 2.7 version of pip.
RUN pip install imcsdk

# Install python 3.6 and pip3, which is critical to connecting to TLS compliant UCS systems
# Patching up because that is just what I do.
RUN yum install python36 python36-pip -y
RUN pip3 install --upgrade pip

#Install Ansible with pip3 so we get ansible fully compatible with python 3.6
RUN pip3 install ansible

# I do not install ansible from the repo because it gets mapped to 2.7 and appears to be difficult to change.
