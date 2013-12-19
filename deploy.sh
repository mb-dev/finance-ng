# global install: nodejs, grunt, grunt-cli, forever, coffee-script, bower
# copy config
git pull
npm install --production
grunt build
forever stop 0
NODE_ENV=production forever start -c coffee server.coffee
