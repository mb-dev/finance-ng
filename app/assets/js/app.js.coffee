#= require ./db
#= require ./reports

'use strict'

# Declare app level module which depends on filters, and services
App = angular.module('app', [
  'ngCookies'
  'ngResource'
  'app.controllers'
  'app.directives'
  'app.filters'
  'app.services'
  'ngRoute'
  'angularMoment'
])

App.config([
  '$routeProvider'
  '$locationProvider'

($routeProvider, $locationProvider, config) ->

  $routeProvider

    .when('/', {templateUrl: '/partials/welcome.html'})

    .when('/accounts/', {templateUrl: '/partials/accounts/index.html'})
    .when('/accounts/new', {templateUrl: '/partials/accounts/form.html', controller: 'LineItemsFormController'})
    .when('/accounts/:account_id/edit', {templateUrl: '/partials/accounts/form.html', controller: 'LineItemsFormController'})
    .when('/accounts/:account_id', {templateUrl: '/partials/accounts/show.html'})

    .when('/line_items/', {templateUrl: '/partials/line_items/index.html', controller: 'LineItemsIndexController'})
    .when('/line_items/new', {templateUrl: '/partials/line_items/form.html', controller: 'LineItemsFormController'})
    .when('/line_items/:line_item_id/edit', {templateUrl: '/partials/line_items/form.html', controller: 'LineItemsFormController'})
    .when('/line_items/:line_item_id', {templateUrl: '/partials/line_items/show.html'})

    .when('/categories/', {templateUrl: '/partials/misc/categories.html'})
    .when('/payees/', {templateUrl: '/partials/misc/payees.html'})
    .when('/batch_assign/', {templateUrl: '/partials/misc/batch_assign.html'})

    .when('/processing_rules/', {templateUrl: '/partials/processing_rules/index.html'})
    .when('/processing_rules/:rule_id/edit', {templateUrl: '/partials/processing_rules/form.html'})
    .when('/processing_rules/:rule_id', {templateUrl: '/partials/processing_rules/show.html'})
    
    .when('/budgets/:year?', {templateUrl: '/partials/budgets/index.html', controller: 'BudgetsIndexController'})
    .when('/budgets/:year/:name', {templateUrl: '/partials/budgets/show.html'})
    .when('/budgets/:year/:name/edit', {templateUrl: '/partials/budgets/form.html'})

    .when('/planned_items/:year?', {templateUrl: '/partials/planned_items/index.html'})
    .when('/planned_items/:year/:name/edit', {templateUrl: '/partials/planned_items/edit.html'})

    .when('/reports/:year?/:month?', {templateUrl: '/partials/reports/index.html'})
    .when('/reports/:year/categories/:item', {templateUrl: '/partials/reports/show.html'})

    .when('/import', {templateUrl: '/partials/misc/import.html'})    

    .when('/login', {templateUrl: '/partials/user/login.html'})
    .when('/register', {templateUrl: '/partials/user/register.html'})
    .when('/edit_profile', {templateUrl: '/partials/user/edit_profile.html'})

    # download backup

    # Catch all
    .otherwise({redirectTo: '/line_items/'})

  # Without server side support html5 must be disabled.
  $locationProvider.html5Mode(true)
])

# Controllers

angular.module('app.controllers', ['app.services'])
  .controller 'LineItemsIndexController', ($scope, $route, fdb) ->
    applyDateChanges = ->
      fdb.then (db) ->
        $scope.lineItems = db.lineItems().getItemsByMonthYear($scope.currentDate.month(), $scope.currentDate.year(), (item) -> item.event_date)


    $scope.currentDate = moment('2012-01-01')
    applyDateChanges()
    $scope.nextMonth = ->
      $scope.currentDate.add('months', 1)
      applyDateChanges()
    $scope.prevMonth = ->
      $scope.currentDate.add('months', -1)
      applyDateChanges()

    return

  .controller 'LineItemsFormController', ($scope, $location) ->
    $scope.onSubmit = ->
      $location.path('/line_items/')
    return

  .controller 'BudgetsIndexController', ($scope, fdb, budgetReportService) ->
    report = null
    applyDateChanges = ->
      fdb.then (db) ->
        reportGenerator = budgetReportService.getReportForYear(db, $scope.currentDate.year())
        $scope.report = reportGenerator.generateReport()
    fdb.then (db) ->
      $scope.yearRanges = db.budgetItems().getYearRange()
    
    $scope.currentDate = moment('2012-01-01')
    $scope.months = moment.monthsShort()
    applyDateChanges()

    $scope.selectYear = (year) ->
      $scope.currentDate.year(year)
      applyDateChanges()

angular.module('app.filters', [])


angular.module('app.services', [])
  .factory 'fdb', ($q) ->
    db = new Database
    db.importDatabase($q)
  .factory 'budgetReportService', ->
    getReportForYear: (db, year) ->
      budgetReport = new BudgetReportView(db, year)
      budgetReport


angular.module('app.directives', ['app.services']).directive 'currencyWithSign', ->
  {
    restrict: 'E',
    link: (scope, elm, attrs) ->
      scope.$watch attrs.amount, (value) ->
        if (typeof value == 'undefined' || value == null)
          elm.html('')
        else if value[0] == '-'
          elm.html('<span class="negative">' + value + '</span>')
        else
          elm.html('<span class="positive">' + value + '</span>')
  }

angular.module('app.filters', [])
  .filter 'bnToFixed', ($window) ->
     (value, format) -> 
      if (typeof value == 'undefined' || value == null)
        return ''

      value.toFixed(2)