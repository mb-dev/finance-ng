// Karma configuration

module.exports = function(karma) {
  karma.set({

    // base path, that will be used to resolve files and exclude
    basePath: '../',


    // frameworks to use
    frameworks: ['jasmine'],


    // list of files / patterns to load in the browser
    files: [
      'http://code.jquery.com/jquery-2.0.3.min.js',
      'test/lib/jasmine-jquery.js',
      'http://ajax.googleapis.com/ajax/libs/angularjs/1.2.6/angular.min.js',
      'http://cdn.jsdelivr.net/sjcl/1.0.0/sjcl.js',
      // Program files
      'public/js/vendor.js',
      'public/js/app.js',

      'test/unit/**/*_spec.*',
      {pattern: 'test/fixtures/*.csv', watched: true, served: true, included: false}
    ],

    // list of files to exclude
    exclude: [
    ],


    // test results reporter to use
    // possible values: 'dots', 'progress', 'junit', 'growl', 'coverage'
    reporters: ['progress', 'osx'],


    // web server port
    port: 9876,

    reportSlowerThan: 1000,


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
      'karma-phantomjs-launcher',
      'karma-osx-reporter',
      'jasmine-jquery'
    ],


    // Continuous Integration mode
    // if true, it capture browsers, run tests and exit
    singleRun: false
  });
};
