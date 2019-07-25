#!/bin/sh

APP_PATH=`echo $0 | awk '{split($0,patharr,"/"); idx=1; while(patharr[idx+1] != "") { if (patharr[idx] != "/") {printf("%s/", patharr[idx]); idx++ }} }'`
APP_PATH=`cd "$APP_PATH"; pwd`

rm "${APP_PATH}/public/"main.*.js
rm "${APP_PATH}/public/"scripts.*.js
rm "${APP_PATH}/public/"runtime.*.js
rm "${APP_PATH}/public/"polyfills*.js
rm "${APP_PATH}/public/"styles.*.css

echo "done"
