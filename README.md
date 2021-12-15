# meta-spdxscanner

1.meta-spdxscanner supports the following SPDX create tools.
- fossology python REST API
- fossology REST API (by curl)

2.meta-spdxscanner supports upload OSS source code to blackduck server by Synopsys Detect.
- blackduck-upload.bbclass

# DEPENDS 

1. fossology-python.bbclass (https://github.com/fossology/fossology-python)
- openembedded-core
- meta-oe/meta-python
- meta-oe/meta-oe
- meta-oe/meta-webserver

2. fossology-rest.bbclass
- openembedded-core
- meta-oe/meta-python

3. blackduck-upload.bbclass
- openembedded-core

# How to use

1.  fossology-python.bbclass
- inherit the folowing class in your conf/local.conf for all of recipes or
  in some recipes which you want.

```
  INHERIT += "fossology-python"
  TOKEN = "eyJ0eXAiO..."
  WAIT_TIME = "..." //Optional, by default, it is 0. If you run hundreds of do_spdx task, 
                    //and your fossology server is not fast enough, it's better to added this value.
  FOSSOLOGY_SERVER = "http://xx.xx.xx.xx:8081/repo" //Optional, by default, it is http://127.0.0.1:8081/repo
  FOLDER_NAME = "xxxx" //Optional, by default, it is the top folder "Software Repository"(folderId=1).
  SPDX_DEPLOY_DIR = "${DeployDir}" //Optional, by default, spdx files will be deployed to ${BUILD_DIR}/tmp/deploy/spdx/
```
Note
- If you want to use fossology-python.bbclass, you have to make sure that fossology server on your host and make sure it works well.
  Please reference to https://hub.docker.com/r/fossology/fossology/.
- TOKEN can be created on fossology server after login by "Admin"->"Users"->"Edit user account"->"Create a new token".

2.  fossology-rest.bbclass
- inherit the folowing class in your conf/local.conf for all of recipes or
  in some recipes which you want.

```
  INHERIT += "fossology-rest"
  TOKEN = "eyJ0eXAiO..."
  FOSSOLOGY_SERVER = "http://xx.xx.xx.xx:8081/repo" //Optional, by default, it is http://127.0.0.1:8081/repo
  FOLDER_NAME = "xxxx" //Optional, by default, it is the top folder "Software Repository"(folderId=1).
  SPDX_DEPLOY_DIR = "${DeployDir}" //Optional, by default, spdx files will be deployed to ${BUILD_DIR}/tmp/deploy/spdx/ 
```
Note
- If you want to use fossology-rest.bbclass, you have to make sure that fossology server on your host and make sure it works well.
  Please reference to https://hub.docker.com/r/fossology/fossology/.
- TOKEN can be created on fossology server after login by "Admin"->"Users"->"Edit user account"->"Create a new token".

3.  blackduck-upload.bbclass
- inherit the folowing class in your conf/local.conf for all of recipes or
  in some recipes which you want.

```
INHERIT += "blackduck-upload"
BD_URI = "https://xxx.yyy.com/"
PRO_NAME = "xxx"
PRO_VER = "xxx"
PROXY_HOST = "xxx"
PROXY_PORT = "xxxx"
PROXY_UN = "xxx"
PROXY_PW = "xxxx"
TOKEN = "NmJ..."

```

