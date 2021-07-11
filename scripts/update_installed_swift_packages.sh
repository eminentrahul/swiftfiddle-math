#!/bin/bash

set -ex
swift package --package-path _Packages/ dump-package > Resources/Views/Package.json
