#!/bin/sh
set -e
java -Xms135152m -Xmx185152m -jar `dirname $0`/juicebox_tools.jar $*
