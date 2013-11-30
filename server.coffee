# "brunch": "1.7.10",
#     "javascript-brunch": "1.7.0",
#     "coffee-script-brunch": "1.7.3",
#     "css-brunch": "1.7.0",
#     "less-brunch": "1.7.0",
#     "auto-reload-brunch": "1.7.1",
#     "uglify-js-brunch": ">= 1.0 < 1.8",
#     "clean-css-brunch": ">= 1.0 < 1.8",
#     "bower": "1.2.7",
#     "jade-angularjs-brunch": "1.1.1",

express = require 'express' 
app = express()

app.configure ->
  app.set('views', __dirname + '/app/views');
  app.set('view engine', 'jade');

  app.use('/css', express.static(__dirname + '/public/css'))
  app.use('/fonts', express.static(__dirname + '/public/fonts'))
  app.use('/js', express.static(__dirname + '/public/js'))
  app.use('/dumps', express.static(__dirname + '/public/dumps'))

  app.use(require("connect-assets")({
    paths: ["app/assets/js", "app/assets/styles", "vendor"]
  }));

  app.get /\/partials\/(.*).html$/, (req, res) ->
    console.log "render #{req.params[0]}"
    res.render('partials/' + req.params[0])

  app.all '/*', (req, res) -> 
    res.render('index')

port = 3333
app.listen port
console.log "Listening on port: #{port}"