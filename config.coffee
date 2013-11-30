exports.config =
  conventions:
    assets: /^no_assets/
    vendor: /^no_vendor/
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
