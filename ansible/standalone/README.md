These examples show how to configure C240 M5 in stand alone using Ansible tasks. 

Ansible tasks are located in the tasks directory. 

A sample inventory file is provided to help you get started:

The following tasks are provided:
- task-ConfigureBios.yaml - BIOS Configuration based on HPC 
- task-ConfigureBootOrder - Boot order configuration (with limitations)
- task-ConfigureEmailAlert - Configures alert forwarding via email for the CIMC
- task-ConfigureNTP - Sets time servers for the CIMC
- task-ConfigureVIC - Configures interfaces for PXI and Optimizes for Linux
- task-FirmwareUpdate - Uses the API to trigger a firmware update from a given ISO
- task-PowerOnServer - Powers on the server
- task-PowerOffServer - Powers off the server

