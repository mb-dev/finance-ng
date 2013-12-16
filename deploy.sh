# global install: nodejs, brunch, forever, coffee-script, bower
# copy config
npm install
bower install
brunch build --production
NODE_ENV=production forever start -c coffee server.coffee