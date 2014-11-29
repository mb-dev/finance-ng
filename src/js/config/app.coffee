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
  'core.controllers'
  'core.directives'
  'core.filters'
  'ngRoute'
  'angularMoment'
  'mgcrea.ngStrap'
  'checklist-model'
])

App.config ($routeProvider, $locationProvider) ->
  authAndCheckData = (tableList, db, storageService, $rootScope) ->
    setTimeout ->
      if storageService.isAuthenticateTimeAndSet()
        db.getTables(tableList).then (ok) ->
          coffeescript_needs_this_line = true
        , (failure) ->
          $rootScope.$broadcast('auth_fail', failure)
    , 5000
    db

  loadIdbCollections = (otherFunctions = []) ->
    {
      db: ($q, $route, financeidb, storageService, $rootScope) ->
        defer = $q.defer()
        financeidb.loadTables().then ->
          async.each otherFunctions, (func, callback) ->
            func(financeidb, $route).then -> 
              callback()
            , (err) ->
              console.log "Failed #{err}"
          , (err) ->
            defer.resolve(financeidb)
          if storageService.isUserExists() and storageService.getEncryptionKey()
            authAndCheckData(Object.keys(financeidb.tables), financeidb, storageService, $rootScope)
        , (err) ->
          console.log "error loading"
          defer.reject(err)
        defer.promise
    }

  loadBudgetItemsForYear = (db, $route) ->
    year = parseInt($route.current.params.year, 10) or moment().year()
    db.budgetItems().getAllForYear(year).then (budgetItems) ->
      db.preloaded.budgetItems = budgetItems

  loadBudgetItemId = (db, $route) ->
    itemId = parseInt($route.current.params.itemId, 10)
    db.budgetItems().findById(itemId).then (budgetItem) ->
      db.preloaded.budgetItem = budgetItem

  loadPlannedItemsForYear = (db, $route) ->
    year = parseInt($route.current.params.year, 10) or moment().year()
    db.plannedItems().getAllForYear(year).then (plannedItems) ->
      db.preloaded.plannedItems = plannedItems

  loadCategories = (db) ->
    db.categories().getAllKeys().then (categories) ->
      db.preloaded.categories = categories

  loadPayees = (db) ->
    db.payees().getAllKeys().then (payees) ->
      db.preloaded.payees = payees

  loadAccounts = (db) ->
    db.accounts().getAll().then (accounts) ->
      db.preloaded.accounts = accounts

  loadImportedLines = (db) ->
    db.importedLines().getAll().then (importedLines) ->
      db.preloaded.importedLines = {}
      db.preloaded.importedLines[item.content] = true for item in importedLines

  loadProcessingRules = (db) ->
    db.processingRules().getAll().then (processingRules) -> 
      db.preloaded.processingRules = processingRules

  loadAccountId = (db, $route) ->
    itemId = parseInt($route.current.params.itemId, 10)
    db.accounts().findById(itemId).then (account) ->
      db.preloaded.item = account

  loadLineItemsByYear = (db, $route) ->
    year = parseInt($route.current.params.year, 10) or moment().year()
    db.lineItems().getByDynamicFilter({date: {year: year}}).then (lineItems) =>
      db.preloaded.lineItems = lineItems

  loadLineItem = (db, $route) ->
    itemId = parseInt($route.current.params.itemId, 10)
    db.lineItems().findById(itemId).then (item) ->
      db.preloaded.item = item
      db.accounts().findById(item.accountId).then (account) ->
        db.preloaded.account = account

  $routeProvider
    .when('/', {templateUrl: '/partials/home/welcome.html', controller: 'WelcomePageController', resolve: loadIdbCollections([loadAccounts]) })

    .when('/accounts/new', {templateUrl: '/partials/accounts/form.html', controller: 'AccountsFormController', resolve: loadIdbCollections() })
    .when('/accounts/:itemId/edit', {templateUrl: '/partials/accounts/form.html', controller: 'AccountsFormController', resolve: loadIdbCollections([loadAccountId]) })
    .when('/accounts/:itemId', {templateUrl: '/partials/accounts/show.html', controller: 'AccountsShowController', resolve: loadIdbCollections([loadAccountId]) })

    .when('/line_items/new', {templateUrl: '/partials/line_items/form.html', controller: 'LineItemsFormController', resolve: loadIdbCollections([]) })
    .when('/line_items/:itemId/edit', {templateUrl: '/partials/line_items/form.html', controller: 'LineItemsFormController', resolve: loadIdbCollections([loadLineItem]) })
    .when('/line_items/:itemId/split', {templateUrl: '/partials/line_items/split.html', controller: 'LineItemsSplitController', resolve: loadIdbCollections([loadAccounts, loadLineItem]) })
    .when('/line_items/:itemId', {templateUrl: '/partials/line_items/show.html', controller: 'LineItemShowController', resolve: loadIdbCollections([loadLineItem]) })
    .when('/line_items/:year/:month', {templateUrl: '/partials/line_items/index.html', controller: 'LineItemsIndexController', reloadOnSearch: false, resolve: loadIdbCollections() })
    .when('/line_items/', {templateUrl: '/partials/line_items/index.html', controller: 'LineItemsIndexController', resolve: loadIdbCollections() })

    .when('/processing_rules/', {templateUrl: '/partials/processing_rules/index.html'})
    .when('/processing_rules/:itemId/edit', {templateUrl: '/partials/processing_rules/form.html'})
    .when('/processing_rules/:itemId', {templateUrl: '/partials/processing_rules/show.html'})
    
    .when('/budgets/:year?', {templateUrl: '/partials/budgets/index.html', controller: 'BudgetsIndexController', resolve: loadIdbCollections([loadCategories, loadLineItemsByYear, loadBudgetItemsForYear, loadPlannedItemsForYear]) })
    .when('/budgets/:year/new', {templateUrl: '/partials/budgets/form.html', controller: 'BudgetItemsFormController', resolve: loadIdbCollections([loadCategories, loadBudgetItemsForYear]) })
    .when('/budgets/:year/:itemId', {templateUrl: '/partials/budgets/show.html'})
    .when('/budgets/:year/:itemId/edit', {templateUrl: '/partials/budgets/form.html', controller: 'BudgetItemsFormController', resolve: loadIdbCollections([loadCategories, loadBudgetItemsForYear, loadBudgetItemId]) })


    .when('/planned_items/:year?', {templateUrl: '/partials/planned_items/index.html'})
    .when('/planned_items/:year/:name/edit', {templateUrl: '/partials/planned_items/edit.html'})

    .when('/reports/:year?/:month?', {templateUrl: '/partials/reports/index.html', controller: 'ReportsIndexController', resolve: loadIdbCollections([loadCategories]) })
    .when('/reports/:year/categories/:item', {templateUrl: '/partials/reports/show.html', controller: 'ReportsShowController', resolve: loadIdbCollections([loadCategories]) })

    .when('/misc', {templateUrl: '/partials/misc/index.html', controller: 'MiscController', resolve: loadIdbCollections() })
    .when('/misc/import', {templateUrl: '/partials/misc/import.html', controller: 'ImportItemsController', resolve: loadIdbCollections([loadAccounts, loadCategories, loadPayees, loadImportedLines, loadProcessingRules ]) })
    .when('/misc/categories', {templateUrl: '/partials/misc/categories.html', controller: 'MiscCategoriesController', resolve: loadIdbCollections([loadCategories]) })    
    .when('/misc/payees', {templateUrl: '/partials/misc/payees.html', controller: 'MiscPayeesController', resolve: loadIdbCollections([loadPayees]) })
    .when('/misc/processingRules', {templateUrl: '/partials/misc/processingRules.html', controller: 'MiscProcessingRulesController', resolve: loadIdbCollections([loadProcessingRules]) })    
    .when('/misc/importedLines/:year/:month', {templateUrl: '/partials/misc/importedLines.html', controller: 'MiscImportedLinesController', resolve: loadIdbCollections([loadImportedLines]) })    
    .when('/misc/importedLines/', {templateUrl: '/partials/misc/importedLines.html', controller: 'MiscImportedLinesController', resolve: loadIdbCollections([loadImportedLines]) })    


    .when('/login_success', template: 'Loading...', controller: 'LoginOAuthSuccessController')
    .when('/key', {templateUrl: '/partials/user/key.html', controller: 'UserKeyController', resolve:  loadIdbCollections()} )
    .when('/profile', {templateUrl: '/partials/user/profile.html', controller: 'UserProfileController', resolve:  loadIdbCollections() })
    .when('/edit_profile', {templateUrl: '/partials/user/edit_profile.html', controller: 'UserEditProfileController'})
    .when('/logout', {template: 'Logging out...', controller: 'UserLogoutController'})

    # Catch all
    .otherwise({redirectTo: '/'})

  # Without server side support html5 must be disabled.
  $locationProvider.html5Mode(true)

App.run ($rootScope, $location, $injector, $timeout, $window, storageService, userService) ->
  redirectOnFailure = (failure) ->
    if failure.reason == 'not_logged_in'
      storageService.onLogout()
      $location.path '/?refresh'
    else if failure.reason == 'missing_key'
      $location.path '/key'

  $rootScope.appName = 'Finance'
  $rootScope.domain = 'finance'
  $rootScope.headerPath = '/partials/common/finance_header.html'
  $rootScope.loginUrl = userService.oauthUrl($rootScope.domain)

  storageService.setAppName($rootScope.appName, $rootScope.domain)
  
  $rootScope.$on "$routeChangeError", (event, current, previous, rejection) ->
    if rejection.data.reason
      redirectOnFailure(rejection.data)
  
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

  $rootScope.$on 'auth_fail', (event, failure) ->
    if failure.data.reason
      redirectOnFailure(failure.data)

  $rootScope.isActive = (urlPart) =>
    $location.path().indexOf(urlPart) > 0
  $rootScope.flashSuccess = (msg) ->
    storageService.setSuccessMsg(msg)
  $rootScope.flashNotice = (msg) ->
    storageService.setNoticeMsg(msg)
  $rootScope.showSuccess = (msg) ->
    $rootScope.successMsg = msg
  $rootScope.showError = (msg) ->
    $rootScope.errorMsg = msg
  $rootScope.setTitle = (title) ->
    $window.document.title = $rootScope.appName + ' - ' + title

  $rootScope.$on '$viewContentLoaded', ->
    storageService.clearMsgs()
