'use strict'

# Declare app level module which depends on filters, and services
App = angular.module('app', [
  'ngCookies'
  'ngResource'
  'ngSanitize'
  'app.controllers'
  'app.directives'
  'app.filters'
  'app.services'
  'ngRoute'
  'angularMoment'
  'ui.select2',
  'siyfion.sfTypeahead'
  'checklist-model'
])

App.config ($routeProvider, $locationProvider) ->
  authAndCheckData = (tableList, db) ->
    setTimeout ->
      $injector = angular.element('ng-view').injector()
      storageService = $injector.get('storageService')
      if storageService.isAuthenticateTimeAndSet()
        db.authAndCheckData(tableList(db)).then (ok) ->
          coffeescript_needs_this_line = true
        , (failure) ->
          $injector.get('$rootScope').$broadcast('auth_fail', failure)
    , 5000
    db

  resolveFDb = (tableList) ->
    {
      db: (fdb) -> 
        fdb.getTables(tableList(fdb)).then -> authAndCheckData(tableList, fdb)
    }

  $routeProvider
    .when('/', {templateUrl: '/partials/home/welcome.html', controller: 'WelcomePageController'})

    .when('/accounts/', {templateUrl: '/partials/accounts/index.html', controller: 'AccountsIndexController', resolve: resolveFDb((fdb) -> [fdb.tables.accounts]) })
    .when('/accounts/new', {templateUrl: '/partials/accounts/form.html', controller: 'AccountsFormController', resolve: resolveFDb((fdb) -> [fdb.tables.accounts]) })
    .when('/accounts/:itemId/edit', {templateUrl: '/partials/accounts/form.html', controller: 'AccountsFormController', resolve: resolveFDb((fdb) -> [fdb.tables.accounts]) })
    .when('/accounts/:itemId', {templateUrl: '/partials/accounts/show.html', controller: 'AccountsShowController', resolve: resolveFDb((fdb) -> [fdb.tables.accounts]) })

    .when('/line_items/new', {templateUrl: '/partials/line_items/form.html', controller: 'LineItemsFormController', resolve: resolveFDb((fdb) ->[fdb.tables.lineItems, fdb.tables.categories, fdb.tables.payees, fdb.tables.accounts]) })
    .when('/line_items/:itemId/edit', {templateUrl: '/partials/line_items/form.html', controller: 'LineItemsFormController', resolve: resolveFDb((fdb) ->[fdb.tables.lineItems, fdb.tables.categories, fdb.tables.payees, fdb.tables.accounts]) })
    .when('/line_items/:itemId/split', {templateUrl: '/partials/line_items/split.html', controller: 'LineItemsSplitController', resolve: resolveFDb((fdb) ->[fdb.tables.lineItems, fdb.tables.categories, fdb.tables.accounts]) })
    .when('/line_items/:itemId', {templateUrl: '/partials/line_items/show.html', controller: 'LineItemShowController', resolve: resolveFDb((fdb) ->[fdb.tables.lineItems, fdb.tables.accounts]) })
    .when('/line_items/:year/:month', {templateUrl: '/partials/line_items/index.html', controller: 'LineItemsIndexController', reloadOnSearch: false, resolve: resolveFDb((fdb) ->[fdb.tables.lineItems, fdb.tables.accounts]) })
    .when('/line_items/', {templateUrl: '/partials/line_items/index.html', controller: 'LineItemsIndexController', resolve: resolveFDb((fdb) ->[fdb.tables.lineItems]) })

    .when('/categories/', {templateUrl: '/partials/misc/categories.html'})
    .when('/payees/', {templateUrl: '/partials/misc/payees.html'})
    .when('/batch_assign/', {templateUrl: '/partials/misc/batch_assign.html'})

    .when('/processing_rules/', {templateUrl: '/partials/processing_rules/index.html'})
    .when('/processing_rules/:itemId/edit', {templateUrl: '/partials/processing_rules/form.html'})
    .when('/processing_rules/:itemId', {templateUrl: '/partials/processing_rules/show.html'})
    
    .when('/budgets/:year?', {templateUrl: '/partials/budgets/index.html', controller: 'BudgetsIndexController', resolve: resolveFDb((fdb) ->[fdb.tables.budgetItems, fdb.tables.lineItems]) })
    .when('/budgets/:year/new', {templateUrl: '/partials/budgets/form.html', controller: 'BudgetItemsFormController', resolve: resolveFDb((fdb) ->[fdb.tables.budgetItems, fdb.tables.categories]) })
    .when('/budgets/:year/:itemId', {templateUrl: '/partials/budgets/show.html'})
    .when('/budgets/:year/:itemId/edit', {templateUrl: '/partials/budgets/form.html', controller: 'BudgetItemsFormController', resolve: resolveFDb((fdb) ->[fdb.tables.budgetItems, fdb.tables.categories]) })


    .when('/planned_items/:year?', {templateUrl: '/partials/planned_items/index.html'})
    .when('/planned_items/:year/:name/edit', {templateUrl: '/partials/planned_items/edit.html'})

    .when('/reports/:year?/:month?', {templateUrl: '/partials/reports/index.html', controller: 'ReportsIndexController', resolve: resolveFDb((fdb) ->[fdb.tables.lineItems, fdb.tables.categories]) })
    .when('/reports/:year/categories/:item', {templateUrl: '/partials/reports/show.html', controller: 'ReportsShowController', resolve: resolveFDb((fdb) ->[fdb.tables.lineItems, fdb.tables.categories])})

    .when('/misc', {templateUrl: '/partials/misc/index.html'})    
    .when('/misc/import', {templateUrl: '/partials/misc/import.html', controller: 'ImportItemsController', resolve: resolveFDb((fdb) ->[fdb.tables.accounts, fdb.tables.categories, fdb.tables.payees, fdb.tables.lineItems, fdb.tables.importedLines, fdb.tables.processingRules]) })    
    .when('/misc/categories', {templateUrl: '/partials/misc/categories.html', controller: 'MiscCategoriesController', resolve: resolveFDb((fdb) ->[fdb.tables.categories]) })    
    .when('/misc/payees', {templateUrl: '/partials/misc/payees.html', controller: 'MiscPayeesController', resolve: resolveFDb((fdb) ->[fdb.tables.payees]) })    
    .when('/misc/processingRules', {templateUrl: '/partials/misc/processingRules.html', controller: 'MiscProcessingRulesController', resolve: resolveFDb((fdb) ->[fdb.tables.processingRules]) })    
    .when('/misc/importedLines/:year/:month', {templateUrl: '/partials/misc/importedLines.html', controller: 'MiscImportedLinesController', resolve: resolveFDb((fdb) ->[fdb.tables.importedLines]) })    
    .when('/misc/importedLines/', {templateUrl: '/partials/misc/importedLines.html', controller: 'MiscImportedLinesController', resolve: resolveFDb((fdb) ->[fdb.tables.importedLines]) })    


    .when('/login_success', template: 'Loading...', controller: 'LoginOAuthSuccessController')
    .when('/login', {templateUrl: '/partials/user/login.html', controller: 'UserLoginController'})
    .when('/key', {templateUrl: '/partials/user/key.html', controller: 'UserKeyController'})
    .when('/register', {templateUrl: '/partials/user/register.html', controller: 'UserLoginController'})
    .when('/profile', {templateUrl: '/partials/user/profile.html', controller: 'UserProfileController' })
    .when('/edit_profile', {templateUrl: '/partials/user/edit_profile.html', controller: 'UserEditProfileController'})
    .when('/logout', {template: 'Logging out...', controller: 'UserLogoutController'})

    # Catch all
    .otherwise({redirectTo: '/'})

  # Without server side support html5 must be disabled.
  $locationProvider.html5Mode(true)

App.run ($rootScope, $location, $injector, $timeout, storageService) ->
  redirectOnFailure = (failure) ->
    if failure.reason == 'not_logged_in'
      $location.path '/login'
    else if failure.reason == 'missing_key'
      $location.path '/key'

  $rootScope.appName = 'Finance'
  $rootScope.domain = 'finance'
  storageService.setAppName($rootScope.appName, $rootScope.domain)
  
  $rootScope.$on "$routeChangeError", (event, current, previous, rejection) ->
    if rejection.status == 403 && rejection.data.reason
      redirectOnFailure(rejection.data)

    if rejection.status == 403 && rejection.data.reason == 'missing_key'
      $location.path '/key'
  
  $rootScope.$on '$routeChangeStart', ->
    $rootScope.currentLocation = $location.path()
    
    if storageService.getSuccessMsg()
      $rootScope.successMsg = storageService.getSuccessMsg()
    if storageService.getNoticeMsg()
      $rootScope.noticeMsg = storageService.getNoticeMsg()
    storageService.clearMsgs()
    $rootScope.userDetails = storageService.getUserDetails()
    $rootScope.loggedIn = $rootScope.userDetails?
    if $rootScope.userDetails
      $rootScope.userDetails.firstName = $rootScope.userDetails.name.split(' ')[0]

  $rootScope.$on 'auth_fail', ->
    if failure.data.reason
      redirectOnFailure(failure.data)

  $rootScope.isActive = (urlPart) =>
    $location.path().indexOf(urlPart) > 0

  $rootScope.flashSuccess = (msg) ->
    storageService.setSuccessMsg(msg)

  $rootScope.flashNotice = (msg) ->
    storageService.setNoticeMsg(msg)

  $rootScope.$on '$viewContentLoaded', ->
    storageService.clearMsgs()
