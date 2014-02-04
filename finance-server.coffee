express = require 'express' 

exports.app = app = express()
app.use(express.favicon())
app.use(express.static(__dirname + '/public'))

if app.settings.env == 'development'
  apps = [
    { name: 'Journal', url: 'http://journal.moshebergman.local.com:4000' }
    { name: 'Finance', url: 'http://finance.moshebergman.local.com:3000' }
  ]
else
  apps = [
    { name: 'Journal', url: 'http://journal.moshebergman.com' }
    { name: 'Finance', url: 'http://finance.moshebergman.com' }
  ]

app.engine('.html', require('ejs').__express);
app.set('view engine', 'html');
app.set('views', __dirname + '/server/views');

app.get '/css/*', (req, res) -> res.send(404, 'Not found')
app.get '/images/*', (req, res) -> res.send(404, 'Not found')
app.get '/fonts/*', (req, res) -> res.send(404, 'Not found')
app.get '/js/*', (req, res) -> res.send(404, 'Not found')
app.get '/partials/*', (req, res) -> res.send(404, 'Not found')
app.get '/*', (req, res) -> res.render('index', {apps: apps})

serverPort = 3000
console.log "FinanceNG - Listening on port: #{serverPort} - #{app.settings.env}"

if process.env.NODE_ENV == 'development'
  app.listen serverPort, "0.0.0.0"
else
  app.listen serverPort
