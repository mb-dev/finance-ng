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
  globalResolve = {db: 'fdb'}
  $routeProvider

    .when('/', {templateUrl: '/partials/welcome.html'})

    .when('/accounts/', {templateUrl: '/partials/accounts/index.html', controller: 'AccountsIndexController', resolve: globalResolve})
    .when('/accounts/new', {templateUrl: '/partials/accounts/form.html', controller: 'AccountsFormController', resolve: globalResolve})
    .when('/accounts/:itemId/edit', {templateUrl: '/partials/accounts/form.html', controller: 'AccountsFormController', resolve: globalResolve})
    .when('/accounts/:itemId', {templateUrl: '/partials/accounts/show.html', controller: 'AccountsShowController', resolve: globalResolve})

    .when('/line_items/new', {templateUrl: '/partials/line_items/form.html', controller: 'LineItemsFormController', resolve: globalResolve})
    .when('/line_items/:itemId/edit', {templateUrl: '/partials/line_items/form.html', controller: 'LineItemsFormController', resolve: globalResolve})
    .when('/line_items/:itemId', {templateUrl: '/partials/line_items/show.html', controller: 'LineItemShowController', resolve: globalResolve})
    .when('/line_items/:year/:month', {templateUrl: '/partials/line_items/index.html', controller: 'LineItemsIndexController', reloadOnSearch: false, resolve: globalResolve})
    .when('/line_items/', {templateUrl: '/partials/line_items/index.html', controller: 'LineItemsIndexController', resolve: globalResolve})

    .when('/categories/', {templateUrl: '/partials/misc/categories.html'})
    .when('/payees/', {templateUrl: '/partials/misc/payees.html'})
    .when('/batch_assign/', {templateUrl: '/partials/misc/batch_assign.html'})

    .when('/processing_rules/', {templateUrl: '/partials/processing_rules/index.html'})
    .when('/processing_rules/:itemId/edit', {templateUrl: '/partials/processing_rules/form.html'})
    .when('/processing_rules/:itemId', {templateUrl: '/partials/processing_rules/show.html'})
    
    .when('/budgets/:year?', {templateUrl: '/partials/budgets/index.html', controller: 'BudgetsIndexController', resolve: globalResolve})
    .when('/budgets/:year/:itemId', {templateUrl: '/partials/budgets/show.html'})
    .when('/budgets/:year/:itemId/edit', {templateUrl: '/partials/budgets/form.html', controller: 'BudgetItemsFormController', resolve: globalResolve})

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

  .controller 'AccountsIndexController', ($scope, $route, db) ->
    $scope.accounts = db.accounts().getAll().toArray()
    return

  .controller 'AccountsFormController', ($scope, $routeParams, $location, db) ->
    updateFunc = null
    if Lazy($location.$$url).endsWith('new')
      $scope.title = 'New account'
      $scope.item = {import_format: 'ProvidentChecking'}
      updateFunc = db.accounts().insert
    else
      $scope.title = 'Edit account'
      $scope.item = db.accounts().findById($routeParams.itemId)
      updateFunc = db.accounts().editItemById

    $scope.importFormats = {ChaseCC: 'Chase CC', ProvidentVisa: 'Provident Visa', ProvidentChecking: 'Provident Checking', Scottrade: 'Scottrade'}

    $scope.onSubmit = ->
      try
        updateFunc($scope.item)
      catch err
        if err == 'idAlreadyExists'
          $scope.error = "Item already exists"
          return
      $location.path('/accounts/')
    return

  .controller 'AccountsShowController', ($scope, $routeParams, db) ->
    $scope.item = db.accounts().findById($routeParams.itemId)

  .controller 'LineItemsIndexController', ($scope, $routeParams, $location, db) ->
    applyDateChanges = ->
      $scope.lineItems = db.lineItems().getItemsByMonthYear($scope.currentDate.month(), $scope.currentDate.year(), (item) -> item.event_date).toArray()

    $scope.currentDate = moment('2012-01-01')
    if $routeParams.month && $routeParams.year
      $scope.currentDate.year(+$routeParams.year).month(+$routeParams.month - 1)

    applyDateChanges()
    $scope.nextMonth = ->
      $scope.currentDate.add('months', 1)
      applyDateChanges()
      $location.path('/line_items/' + $scope.currentDate.year().toString() + '/' + ($scope.currentDate.month()+1).toString())
    $scope.prevMonth = ->
      $scope.currentDate.add('months', -1)
      applyDateChanges()
      $location.path('/line_items/' + $scope.currentDate.year().toString() + '/' + ($scope.currentDate.month()+1).toString())

    return

  .controller 'LineItemsFormController', ($scope, $routeParams, $location, db) ->
    updateFunc = null
    if Lazy($location.$$url).endsWith('new')
      $scope.title = 'New line item'
      $scope.item = {date: moment().format('L'), tags: []}
      updateFunc = db.lineItems().insert
    else
      $scope.title = 'Edit line item'
      $scope.item = db.lineItems().findById($routeParams.itemId)
      updateFunc = db.lineItems().editItemById
    $scope.accounts = db.accounts().getAll().toArray()
    $scope.onSubmit = ->
      try
        updateFunc($scope.item)
      catch err
        if err == 'idAlreadyExists'
          $scope.error = "Item already exists"
          return
      $location.path('/line_items/')
    return

  .controller 'LineItemShowController', ($scope, $routeParams, db) ->
    $scope.item = db.lineItems().findById($routeParams.itemId)
    $scope.account = db.accounts().findById($scope.item.account_id)

  .controller 'BudgetsIndexController', ($scope, $routeParams, $location, db, budgetReportService) ->
    report = null
    applyDateChanges = ->
        reportGenerator = budgetReportService.getReportForYear(db, $scope.currentDate.year())
        $scope.report = reportGenerator.generateReport()
    $scope.yearRanges = db.budgetItems().getYearRange()
    
    $scope.currentDate = moment('2012-01-01')
    if $routeParams.year
      $scope.currentDate.year(+$routeParams.year)
    $scope.months = moment.monthsShort()
    applyDateChanges()

    $scope.selectYear = (year) ->
      $scope.currentDate.year(year)
      $location.path('/budgets/' + $scope.currentDate.year().toString())

  .controller 'BudgetItemsFormController', ($scope, $routeParams, $location, db) ->
    updateFunc = null
    if Lazy($location.$$url).endsWith('new')
      $scope.title = 'New budget item'
      $scope.item = {budget_year: moment().year()}
      updateFunc = db.budgetItems().insert
    else
      $scope.title = 'Edit account'
      $scope.item = db.budgetItems().findById($routeParams.itemId)
      updateFunc = db.budgetItems().editItemById

    $scope.categories = db.lineItems().getCategories()

    $scope.onSubmit = ->
      try
        updateFunc($scope.item)
      catch err
        if err == 'idAlreadyExists'
          $scope.error = "Item already exists"
          return
      $location.path('/budgets/' + $scope.item.budget_year.toString())
    return


angular.module('app.filters', [])
  .filter 'localDate', ($filter) ->
    angularDateFilter = $filter('date')
    (theDate) ->
      angularDateFilter(theDate, 'MM/dd/yyyy')

  .filter 'typeString', ($filter) ->
    (typeInt) ->
      if typeInt == LineItemCollection.EXPENSE then 'Expense' else 'Income'

   .filter 'bnToFixed', ($window) ->
     (value, format) -> 
      if (typeof value == 'undefined' || value == null)
        return ''

      value.toFixed(2)


angular.module('app.services', ['ngStorage'])
  .factory 'fdb', ($q, $sessionStorage, $rootScope) ->
    db = new Database
    db.importDatabase($q, $sessionStorage)
    $rootScope.$on "savestate",  ->
      db.saveStateToLocalStorage($sessionStorage);
    $rootScope.$on "restorestate", ->
      db.loadStateFromLocalStorage($sessionStorage);
    db
  .factory 'budgetReportService', () ->
    getReportForYear: (db, year) ->
      budgetReport = new BudgetReportView(db, year)
      budgetReport


angular.module('app.directives', ['app.services', 'app.filters'])
  .directive 'currencyWithSign', ->
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
  
  .directive 'dateFormat', ($filter) ->
    dateFilter = $filter('localDate')
    {  
      require: 'ngModel'
      link: (scope, element, attr, ngModelCtrl) ->
        ngModelCtrl.$formatters.unshift (value) ->
          dateFilter(value)
        
        ngModelCtrl.$parsers.push (value) ->
          moment(value).valueOf()          
    }

  .directive 'typeFormat', ($filter) ->
    typeFilter = $filter('typeString')
    {  
      require: 'ngModel'
      link: (scope, element, attr, ngModelCtrl) ->
        ngModelCtrl.$formatters.unshift (value) ->
          typeFilter(value)
        
        ngModelCtrl.$parsers.push (value) ->
          if value == 'Expense' then LineItemCollection.EXPENSE else LineItemCollection.INCOME
    }
 