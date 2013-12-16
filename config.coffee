exports.config =
  modules:
    definition: false
    wrapper: false
  paths:
    public: 'public'
  files:
    javascripts:
      joinTo: 
        'js/app.js': /^app/
        'js/vendor.js': /^(vendor)/
      order:
        before: [
          '/app/assets/js/config/app.coffee'
          '/vendor/js/angular/angular.js'
        ]
    stylesheets:
      joinTo:
        'css/app.css': /^(app\/assets\/styles\/app-styles.less)/
        'css/vendor.css': /^(vendor)/
      order:
        before: [
          'app/app.less'
        ]
    

  plugins:
    jade:
      pretty: yes # Adds pretty-indentation whitespaces to output (false by default)
    jade_angular:
      modules_folder: 'partials'
      locals: {}

  # server:
  #   path: 'server.coffee'
  #   port: 3333
  #   base: '/_public'
  #   run: yes

  # Enable or disable minifying of result js / css files.
  # minify: true
