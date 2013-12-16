module.exports = function(grunt) {

  // Project configuration.
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    coffee: {
      options: {
        
      },
      files: {
        expand: true,
        flatten: true,
        src: '**/*.coffee',
        dest: 'build/js/app',
        ext: '.js',
        cwd: 'app/assets/js'
      }
    },
    copy: {
      scripts: {
        files: {
          expand: true,
          flatten: true,
          src: '**/*.js',
          dest: 'build/js/vendor',
          cwd: 'vendor/js'
        }
      },
      styles: {
        files: [{
          expand: true,
          flatten: true,
          src: '**/*.css',
          dest: 'build/css/vendor',
          cwd: 'vendor/styles'
        }]
      }
    },
    less: {
      dev: {
        files: [{
          src: ['app/assets/styles/app.less'],
          dest: 'public/css/app.css'
        }]
      }
    },
    concat: {
      scripts: {
        files: [{
          src: ['build/js/app/*.js'],
          dest: 'public/js/app.js'
        }, {
          src: ['build/js/vendor/*.js'],
          dest: 'public/js/vendor.js'
        }],
      },
      styles: {
        files: [{
          src: ['build/css/vendor/*.css'],
          dest: 'public/css/vendor.css'
        }]
      }
    },
    jade: {
      compile: {
        options: {
          data: {
            debug: false
          }
        },
        files: [
          {
            expand: true,
            src: '**/*.jade',
            dest: 'public/partials',
            ext: '.html',
            cwd: 'app/views/partials/'
          }
        ]
      }
    },
    watch: {
      css: {
        files: ['app/assets/**/*.less', 'vendor/**/*.less'],
        options: {
          livereload: true,
        }
      },
      coffeescript: {
        files: ['app/**/*.coffee'],
        tasks: ['scripts'],
        options: {
          livereload: true,
        }
      },
      jade: {
        files: ['app/views/**/*.jade'],
        tasks: ['jade'],
        options: {
          livereload: true,
        }
      }
    },
    nodemon: {
      dev: {
        options: {
          file: 'server.coffee',
          env: {
            PORT: '3333'
          }
        }
      }
    },
    concurrent: {
      dev: {
        tasks: ['watch'],
        options: {
          logConcurrentOutput: true
        }
      }
    }
  });

  // Load the plugin that provides the "uglify" task.
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-nodemon');
  // grunt.loadNpmTasks('grunt-concurrent');
  grunt.loadNpmTasks('grunt-contrib-jade');
  grunt.loadNpmTasks('grunt-contrib-copy');
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-contrib-concat');
  grunt.loadNpmTasks('grunt-contrib-less');

  // Default task(s).
  grunt.registerTask('scripts','', ['copy:scripts', 'coffee', 'concat:scripts']);
  grunt.registerTask('styles','', ['copy:styles', 'less', 'concat:styles']);
  grunt.registerTask('build','', ['scripts']);

};