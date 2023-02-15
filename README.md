

# Installation

## Search and replace values
Search and replace ```CHANGEME```  
Search and replace ```domain.com```  
Search and replace ```domain-com```  
Search and replace ```P@$$word123!```  
Search and replace ```example@domain.com```  
Search and replace ```192.168.x.x```  
Search and replace ```x.x.x.x```  

## Run script

```
cd lib/
# make sure .env file values are replaced
# run script
bash run.sh
```

This will bootstrap a target debian based server with k3s
- install k3s with ansible
- bootstrap helm charts with helmfile
- bootstrap argocd installation
- bootstrap argocd app-of-apps

# Use with caution

This repository is still a rough draft but does run my day to day homelab services

