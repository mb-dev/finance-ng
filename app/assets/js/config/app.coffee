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
  'fileSystem',
  'siyfion.sfTypeahead'
  'checklist-model'
])

App.config ($routeProvider, $locationProvider) ->
  resolveFDb = (tableList) ->
    {
      db: (fdb) -> 
        fdb.getTables(tableList(fdb))
    }

  resolveMDb = (tableList) ->
    {
      db: (mdb) -> 
        mdb.getTables(tableList(mdb))
    }

  memoryNgAllDb = (mdb) -> [mdb.tables.memories, mdb.tables.events, mdb.tables.people, mdb.tables.categories]
  
  $routeProvider
    .when('/', {templateUrl: '/partials/welcome.html'})

    .when('/accounts/', {templateUrl: '/partials/accounts/index.html', controller: 'AccountsIndexController', resolve: resolveFDb((fdb) -> [fdb.tables.accounts]) })
    .when('/accounts/new', {templateUrl: '/partials/accounts/form.html', controller: 'AccountsFormController', resolve: resolveFDb((fdb) -> [fdb.tables.accounts]) })
    .when('/accounts/:itemId/edit', {templateUrl: '/partials/accounts/form.html', controller: 'AccountsFormController', resolve: resolveFDb((fdb) -> [fdb.tables.accounts]) })
    .when('/accounts/:itemId', {templateUrl: '/partials/accounts/show.html', controller: 'AccountsShowController', resolve: resolveFDb((fdb) -> [fdb.tables.accounts]) })

    .when('/line_items/new', {templateUrl: '/partials/line_items/form.html', controller: 'LineItemsFormController', resolve: resolveFDb((fdb) ->[fdb.tables.lineItems, fdb.tables.categories, fdb.tables.payees, fdb.tables.accounts]) })
    .when('/line_items/:itemId/edit', {templateUrl: '/partials/line_items/form.html', controller: 'LineItemsFormController', resolve: resolveFDb((fdb) ->[fdb.tables.lineItems, fdb.tables.categories, fdb.tables.payees, fdb.tables.accounts, fdb.tables.processingRules]) })
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
    .when('/budgets/:year/:itemId', {templateUrl: '/partials/budgets/show.html'})
    .when('/budgets/:year/:itemId/edit', {templateUrl: '/partials/budgets/form.html', controller: 'BudgetItemsFormController', resolve: resolveFDb((fdb) ->[fdb.tables.budgetItems]) })

    .when('/planned_items/:year?', {templateUrl: '/partials/planned_items/index.html'})
    .when('/planned_items/:year/:name/edit', {templateUrl: '/partials/planned_items/edit.html'})

    .when('/reports/:year?/:month?', {templateUrl: '/partials/reports/index.html', controller: 'ReportsIndexController', resolve: resolveFDb((fdb) ->[fdb.tables.lineItems, fdb.tables.categories]) })
    .when('/reports/:year/categories/:item', {templateUrl: '/partials/reports/show.html'})

    .when('/misc', {templateUrl: '/partials/misc/index.html'})    
    .when('/misc/import', {templateUrl: '/partials/misc/import.html', controller: 'ImportItemsController', resolve: resolveFDb((fdb) ->[fdb.tables.accounts, fdb.tables.categories, fdb.tables.payees, fdb.tables.lineItems, fdb.tables.importedLines, fdb.tables.processingRules]) })    
    .when('/misc/categories', {templateUrl: '/partials/misc/categories.html', controller: 'MiscCategoriesController', resolve: resolveFDb((fdb) ->[fdb.tables.categories]) })    
    .when('/misc/payees', {templateUrl: '/partials/misc/payees.html', controller: 'MiscPayeesController', resolve: resolveFDb((fdb) ->[fdb.tables.payees]) })    
    .when('/misc/processingRules', {templateUrl: '/partials/misc/processingRules.html', controller: 'MiscProcessingRulesController', resolve: resolveFDb((fdb) ->[fdb.tables.processingRules]) })    

    .when('/login_success', redirectTo: '/welcome/')
    .when('/login', {templateUrl: '/partials/user/login.html', controller: 'UserLoginController'})
    .when('/key', {templateUrl: '/partials/user/key.html', controller: 'UserKeyController'})
    .when('/register', {templateUrl: '/partials/user/register.html'})
    .when('/profile', {templateUrl: '/partials/user/profile.html', controller: 'UserProfileController' })
    .when('/edit_profile', {templateUrl: '/partials/user/edit_profile.html', controller: 'UserEditProfileController'})

    # download backup

    # memories
    .when('/journal/', {templateUrl: '/partials/journal/index.html', controller: 'JournalIndexController', resolve: resolveMDb(memoryNgAllDb) })

    .when('/categories/', {templateUrl: '/partials/categories/index.html', controller: 'CategoriesIndexController', resolve: resolveMDb(memoryNgAllDb) })

    .when('/memories/new', {templateUrl: '/partials/memories/form.html', controller: 'MemoriesFormController', resolve: resolveMDb(memoryNgAllDb) })
    .when('/memories/:itemId/edit', {templateUrl: '/partials/memories/form.html', controller: 'MemoriesFormController', resolve: resolveMDb(memoryNgAllDb) })
    .when('/memories/:year/:month', {templateUrl: '/partials/memories/index.html', controller: 'MemoriesIndexController', reloadOnSearch: false, resolve: resolveMDb(memoryNgAllDb) })
    .when('/memories/:itemId', {templateUrl: '/partials/memories/show.html', controller: 'MemoriesShowController', resolve: resolveMDb(memoryNgAllDb) })
    .when('/memories/', {templateUrl: '/partials/memories/index.html', controller: 'MemoriesIndexController', reloadOnSearch: false, resolve: resolveMDb(memoryNgAllDb) })

    .when('/events/new', {templateUrl: '/partials/events/form.html', controller: 'EventsFormController', resolve: resolveMDb(memoryNgAllDb) })
    .when('/events/:itemId/edit', {templateUrl: '/partials/events/form.html', controller: 'EventsFormController', resolve: resolveMDb(memoryNgAllDb) })
    .when('/events/:year/:month', {templateUrl: '/partials/events/index.html', controller: 'EventsIndexController', reloadOnSearch: false, resolve: resolveMDb(memoryNgAllDb) })
    .when('/events/:itemId', {templateUrl: '/partials/events/show.html', controller: 'EventsShowController', resolve: resolveMDb(memoryNgAllDb) })
    .when('/events/', {templateUrl: '/partials/events/index.html', controller: 'EventsIndexController', reloadOnSearch: false, resolve: resolveMDb(memoryNgAllDb) })

    .when('/people/new', {templateUrl: '/partials/people/form.html', controller: 'PeopleFormController', resolve: resolveMDb(memoryNgAllDb) })
    .when('/people/:itemId/edit', {templateUrl: '/partials/people/form.html', controller: 'PeopleFormController', resolve: resolveMDb(memoryNgAllDb) })
    .when('/people/', {templateUrl: '/partials/people/index.html', controller: 'PeopleIndexController', reloadOnSearch: false, resolve: resolveMDb(memoryNgAllDb) })
    .when('/people/:itemId', {templateUrl: '/partials/people/show.html', controller: 'PeopleShowController', resolve: resolveMDb(memoryNgAllDb) })


    # Catch all
    .otherwise({redirectTo: '/'})

  # Without server side support html5 must be disabled.
  $locationProvider.html5Mode(true)

App.run ($rootScope, $location, $injector) ->
  $rootScope.$on "$routeChangeError", (event, current, previous, rejection) ->
    if rejection.status == 403 && rejection.data.reason == 'not_logged_in'
      $location.path '/login'

    if rejection.status == 403 && rejection.data.reason == 'missing_key'
      $location.path '/key'
  
  $rootScope.$on '$routeChangeStart', ->
    $rootScope.currentLocation = $location.path()
    $sessionStorage = $injector.get('$sessionStorage')
    if $sessionStorage.successMsg
      $rootScope.successMsg = $sessionStorage.successMsg
      $sessionStorage.successMsg = null

  $rootScope.isActive = (urlPart) =>
    $location.path().indexOf(urlPart) > 0

  $rootScope.flashSuccess = (msg) ->
    $sessionStorage = $injector.get('$sessionStorage')
    $sessionStorage.successMsg = msg

  $rootScope.$on '$viewContentLoaded', ->
    $sessionStorage = $injector.get('$sessionStorage')
    $sessionStorage.successMsg = null
    $sessionStorage.errorMsg = null    

angular.module('app.controllers', ['app.services', 'app.importers'])