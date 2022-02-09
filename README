meta-spdxscanner
================

1.meta-spdxscanner supports the following SPDX create tools.

  - fossology python REST API
 
  - scancode-tk
 
  - fossology REST API (by curl)

2.meta-spdxscanner supports upload OSS source code to blackduck server by Synopsys Detect.

  - blackduck-upload.bbclass

DEPENDS
-----------------------

For fossology-python.bbclass 

  - [fossology server](https://hub.docker.com/r/fossology/fossology/)
  
  - [fossology-python](https://github.com/fossology/fossology-python)

  - openembedded-core

  - meta-oe/meta-python

  - meta-oe/meta-oe

  - meta-oe/meta-webserver


For scancode-tk.bbclass

  - openembedded-core

  - meta-oe/meta-python


For fossology-rest.bbclass

  - [fossology server](https://hub.docker.com/r/fossology/fossology/)

  - openembedded-core

  - meta-oe/meta-python


For blackduck-upload.bbclass

  - openembedded-core



How to use
-----------------------

Now, meta-spdxscanner provides three methods as following to create spdx files. Please select one to use.

First, edit the conf/local.conf file, select one module to enable it.

1.fossology-python.bbclass

```
  $ cat conf/local.conf
  ...
  INHERIT += "fossology-python"
  TOKEN = "eyJ0eXAiO..."
  WAIT_TIME = "..." //Optional, by default, it is 0. If you run hundreds of do_spdx task, 
                    //and your fossology server is not fast enough, it's better to added this value.
  FOSSOLOGY_SERVER = "http://xx.xx.xx.xx:8081/repo" //Optional, by default, it is http://127.0.0.1:8081/repo
  FOLDER_NAME = "xxxx" //Optional, by default, it is the top folder "Software Repository"(folderId=1).
  SPDX_DEPLOY_DIR = "${DeployDir}" //Optional, by default, spdx files will be deployed to ${BUILD_DIR}/tmp/deploy/spdx/
  ...
```
  Note

  - If you want to use fossology-python.bbclass, you have to make sure that fossology server on your host and make sure it works well.
    Please reference to https://hub.docker.com/r/fossology/fossology/.

  - TOKEN can be created on fossology server after login by "Admin"->"Users"->"Edit user account"->"Create a new token".

2.scancode-tk.bbclass

  - inherit the folowing class in your conf/local.conf.

```
  PREFERRED_VERSION_python3-pluggy-native = "0.13.1"
  INHERIT += "scancode-tk"
```

3.fossology-rest.bbclass

  - inherit the folowing class in your conf/local.conf.

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

Finished editing the conf/local.con file, you can get spdx files whatever your build by bitbake. For example:
  - For what your build(e.g, openssl) and the dependences.
```
    $ bitbake openssl
```
  - Only get a spdx for one recipe(e.g, openssl_%.bb).
```
    $ bitbake openssl -f -c spdx
```
  - Only get spdx files for what will be built for a image file(e.g, core-image-minimal.bb) without building.
```
    $ bitbake --runall=spdx core-image-minimal
```

If you has a blackduck server, you can use the following method to upload source code to the server.

1.blackduck-upload.bbclass

   First, edit the conf/local.conf file under build directory as following:

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
Finished editing the conf/local.con file, you can upload the source code of of recipe by bitbake. For example:
  - For what your build(e.g, openssl) and the dependences.
```
    $ bitbake openssl
```
  - Only upload one OSS(e.g, openssl).
```
    $ bitbake openssl -f -c synopsys_detect
```
  - Only get spdx files for what will be built for a image file(e.g, core-image-minimal.bb) without compiling.
```
    $ bitbake --runall=synopsys_detect core-image-minimal
```

Contributing
------------

To contribute to this layer you should submit the patches for review to the
mailing list (yocto@lists.yoctoproject.org) or to maintainer directly.

Mailing list:

    yocto@lists.yoctoproject.org

Layer maintainer:

    leimaohui@fujitsu.com
