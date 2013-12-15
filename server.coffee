express = require 'express' 
passport = require('passport')
fs = require('fs')

env = process.env.NODE_ENV || 'development'
config = require('./server/config/config')[env]
mongoose = require('mongoose')

mongoose.connect(config.db)

# Bootstrap models
#models_path = __dirname + '/server/models'
#fs.readdirSync(models_path).forEach (file) ->
#  require(models_path + '/' + file) if (file.indexOf('.coffee') >= 0)
require('./server/models/user')

require('./server/config/passport')(passport, config)

app = express()

require('./server/config/express')(app, config, passport)
  
require('./server/config/routes')(app, passport)
  
port = 3333
app.listen port
console.log "Listening on port: #{port}"

exports = module.exports = app