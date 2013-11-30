module.exports = function(grunt) {

  // Project configuration.
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    watch: {
      css: {
        files: ['app/assets/**/*.less', 'vendor/**/*.less'],
        options: {
          livereload: true,
        }
      },
      coffeescript: {
        files: ['app/**/*.coffee'],
        options: {
          livereload: true,
        }
      },
      jade: {
        files: ['app/views/**/*.jade'],
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
  grunt.loadNpmTasks('grunt-concurrent');

  // Default task(s).
  grunt.registerTask('default', ['concurrent::tasks']);

};