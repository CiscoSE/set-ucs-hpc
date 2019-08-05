This docker file creates a docker container based on CentOS and includes Ansible, ucsmsdk and imcsdk. Ansible will use python 3.6, while the SDKs use 2.7. 
Not that ansible is loaded with PIP3 in order to ensure it works with Python 3.6. This was done because ansible had connection problems with UCS when running under python 2.7.
