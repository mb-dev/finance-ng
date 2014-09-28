gulp = require('gulp')
gutil = require('gulp-util')
coffee = require('gulp-coffee')
less = require('gulp-less')
jade = require('gulp-jade')
concat = require('gulp-concat')
gulpif = require('gulp-if')
path = require('path');
debug = require('gulp-debug')
sourcemaps = require('gulp-sourcemaps')
plumber = require('gulp-plumber')

paths = {}
paths.scripts = [
              "src/js/config/modules.coffee"
              "bower_components/mbdev-core/dist/js/core.js"
              "src/js/services/**/*.coffee"
              "src/js/lib/report_generators.coffee"

              "src/js/models/**/*.coffee"
              "src/js/controllers/**/*.coffee"

              "src/js/config/app.coffee"
            ]
paths.styles_base = 'bower_components/mbdev-core/src/css/'
paths.styles = [
  'bower_components/mbdev-core/src/css/*.less'
  'src/css/finance.less'
]
paths.views = ['./src/views/**/*.jade', 'bower_components/mbdev-core/src/views/**/*.jade']

gulp.task 'build-views', ->
  gulp.src(paths.views)
    .pipe(jade().on('error', gutil.log))
    .pipe(gulp.dest('./public/partials'))

gulp.task 'build-js', ->
  gulp.src(paths.scripts)
    .pipe(sourcemaps.init())
    .pipe(gulpif(/[.]coffee$/, coffee({bare: true}).on('error', gutil.log)))
    .pipe(concat('app.js'))
    .pipe(sourcemaps.write('./'))
    .pipe(gulp.dest('public/js'))

gulp.task 'build-css', ->
  gulp.src(paths.styles)    
    .pipe(less(
      paths: [ path.join(paths.styles_base, 'includes/bootstrap'), path.join(paths.styles_base, 'includes/selectize')]
    )).on('error', gutil.log)
    .pipe(concat('app.css'))
    .pipe(gulp.dest('public/css'))

gulp.task 'copy-core', ->
  gulp.src(['bower_components/mbdev-core/dist/js/vendor.js'])
    .pipe(gulp.dest('public/js'));
  gulp.src(['bower_components/mbdev-core/dist/css/vendor.css'])
    .pipe(gulp.dest('public/css'));
  gulp.src(['bower_components/mbdev-core/dist/fonts/**.*'])
    .pipe(gulp.dest('public/fonts'));
            
gulp.task 'watch', ->
  gulp.watch(paths.scripts, ['build-js']);
  gulp.watch(paths.styles, ['build-css']);
  gulp.watch(paths.views, ['build-views']);

gulp.task 'build', ['copy-core', 'build-js', 'build-css', 'build-views']
gulp.task 'start', ['build', 'watch']