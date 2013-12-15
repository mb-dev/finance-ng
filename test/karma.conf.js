// Karma configuration

module.exports = function(karma) {
  karma.configure({

    // base path, that will be used to resolve files and exclude
    basePath: '../',


    // frameworks to use
    frameworks: ['jasmine'],


    // list of files / patterns to load in the browser
    files: [

      // Program files
      'vendor/js/jquery.js',
      'vendor/js/bootstrap.js',
      'vendor/js/moment.js',
      'vendor/js/bignumber.js',
      'vendor/js/lazy.js',
      'vendor/js/angular/_angular.js',
      'vendor/js/angular/angular-mocks.js',
      'vendor/js/angular/angular-resource.js',
      'vendor/js/angular/angular-cookies.js',
      'vendor/js/angular/angular-moment.js',
      'vendor/js/angular/angular-route.js',
      'vendor/js/angular/angular-sanitize.js',
      'vendor/js/angular/ngStorage.js',
      'public/js/app.js',

      'test/unit/**/*_spec.*'
    ],


    // list of files to exclude
    exclude: [
    ],


    // test results reporter to use
    // possible values: 'dots', 'progress', 'junit', 'growl', 'coverage'
    reporters: ['progress', 'osx'],


    // web server port
    port: 9876,


    // cli runner port
    runnerPort: 9100,


    // enable / disable colors in the output (reporters and logs)
    colors: true,


    // level of logging
    // possible values: karma.LOG_DISABLE || karma.LOG_ERROR || karma.LOG_WARN || karma.LOG_INFO || karma.LOG_DEBUG
    logLevel: karma.LOG_INFO,


    // enable / disable watching file and executing tests whenever any file changes
    autoWatch: true,


    // Start these browsers, currently available:
    // - Chrome
    // - ChromeCanary
    // - Firefox
    // - Opera
    // - Safari (only Mac)
    // - PhantomJS
    // - IE (only Windows)
    browsers: ['Chrome'],


    // If browser does not capture in given timeout [ms], kill it
    captureTimeout: 60000,


    // Plugins to load
    plugins: [
      'karma-jasmine',
      'karma-coffee-preprocessor',
      'karma-chrome-launcher',
      'karma-osx-reporter'
    ],


    // Continuous Integration mode
    // if true, it capture browsers, run tests and exit
    singleRun: false
  });
};
