module.exports = (grunt) ->
  
  # Project configuration.
  grunt.initConfig
    pkg: grunt.file.readJSON("package.json")
    coffee:
      options: {}
      files: 
        expand: true
        flatten: true
        src: "**/*.coffee"
        dest: "build/js/app"
        ext: ".js"
        cwd: "app/assets/js"

    copy:
      scripts:
        files: [
          expand: true
          flatten: true
          src: "**/*.js"
          dest: "build/js/vendor"
          cwd: "vendor/js"
        ]
      css:
        files: [
          expand: true
          flatten: true
          src: "**/*.css"
          dest: "build/css/vendor"
          cwd: "vendor/css"
        ]
      fonts:
        files: [
          expand: true
          flatten: true
          src: "**/*.*"
          dest: "public/fonts"
          cwd: "app/assets/fonts" 
        ]
      images:
        files: [
          expand: true
          flatten: true
          src: "**/*.*"
          dest: "public/images"
          cwd: "app/assets/images" 
        ]

    less:
      dev:
        files: [
          src: ["app/assets/css/app.less"]
          dest: "public/css/app.css"
        ]

    concat:
      scripts:
        files: 
          "public/js/app.js": [
              "build/js/app/db.js"
              "build/js/app/app.js"
              "build/js/app/accounts.js"
              "build/js/app/budget_items.js"
              "build/js/app/events.js"
              "build/js/app/categories.js"
              "build/js/app/line_items.js"
              "build/js/app/memories.js"
              "build/js/app/people.js"
              "build/js/app/journal.js"
              "build/js/app/reports.js"
              "build/js/app/user.js"
              "build/js/app/common.js" 
            ]
          "public/js/vendor.js": [
            'build/js/vendor/bootstrap.js',
            'build/js/vendor/moment.js',
            'build/js/vendor/bignumber.js',
            'build/js/vendor/lazy.js',
            'build/js/vendor/select2.js',
            'build/js/vendor/angular-mocks.js'
            'build/js/vendor/angular-resource.js'
            'build/js/vendor/angular-cookies.js'
            'build/js/vendor/angular-moment.js'
            'build/js/vendor/angular-route.js'
            'build/js/vendor/angular-sanitize.js'
            'build/js/vendor/angular-select2.js'
            'build/js/vendor/angular-strap-typeahead.js'
            'build/js/vendor/ngStorage.js'
            'build/js/vendor/pickadate.js'
            'build/js/vendor/pickadate.date.js'
            'build/js/vendor/pickadate.time.js'
          ]
      css:
        files: [
          src: ["build/css/vendor/*.css"]
          dest: "public/css/vendor.css"
        ]

    jade:
      compile:
        options:
          data:
            debug: false

        files: [
          expand: true
          src: "**/*.jade"
          dest: "public/partials"
          ext: ".html"
          cwd: "app/views/partials/"
        ]

    watch:
      css:
        files: ["app/assets/**/*.less", "vendor/**/*.less"]
        tasks: ["css"]
        options:
          livereload: true

      coffeescript:
        files: ["app/**/*.coffee"]
        tasks: ["scripts"]
        options:
          livereload: true

      jade:
        files: ["app/views/**/*.jade"]
        tasks: ["templates"]
        options:
          livereload: true

    nodemon:
      dev:
        options:
          file: "server.coffee"
          env:
            PORT: "3333"

    concurrent:
      dev:
        tasks: ["watch"]
        options:
          logConcurrentOutput: true

  
  # Load the plugin that provides the "uglify" task.
  grunt.loadNpmTasks "grunt-contrib-watch"
  grunt.loadNpmTasks "grunt-nodemon"
  
  # grunt.loadNpmTasks('grunt-concurrent');
  grunt.loadNpmTasks "grunt-contrib-jade"
  grunt.loadNpmTasks "grunt-contrib-copy"
  grunt.loadNpmTasks "grunt-contrib-coffee"
  grunt.loadNpmTasks "grunt-contrib-uglify"
  grunt.loadNpmTasks "grunt-contrib-concat"
  grunt.loadNpmTasks "grunt-contrib-less"
  
  # Default task(s).
  grunt.registerTask "scripts", "", ["copy:scripts", "coffee", "concat:scripts"]
  grunt.registerTask "css", "", ["copy:css", "less", "concat:css"]
  grunt.registerTask "templates", "", ["jade"]
  grunt.registerTask "fonts", "", ["copy:fonts"]
  grunt.registerTask "images", "", ["copy:images"]
  grunt.registerTask "build", "", ["scripts", "css", "templates", "fonts", "images"]