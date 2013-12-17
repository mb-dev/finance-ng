# global install: nodejs, brunch, forever, coffee-script, bower
# copy config
npm install
bower install
grunt build
NODE_ENV=production forever start -c coffee server.coffee
