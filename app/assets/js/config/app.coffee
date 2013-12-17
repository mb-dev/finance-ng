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

App.config ($routeProvider, $locationProvider) ->
  resolveDb = (tableList = []) ->
    {
      db: (fdb) -> 
        fdb.getTables(tableList)
    }

  memoryNgAllDb = [Database.MEMORIES_TBL, Database.EVENTS_TBL, Database.PEOPLE_TBL, Database.MEMORY_GRAPH_TBL]
  
  $routeProvider
    .when('/', {templateUrl: '/partials/welcome.html'})

    .when('/accounts/', {templateUrl: '/partials/accounts/index.html', controller: 'AccountsIndexController', resolve: resolveDb([Database.ACCOUNTS_TBL]) })
    .when('/accounts/new', {templateUrl: '/partials/accounts/form.html', controller: 'AccountsFormController', resolve: resolveDb([Database.ACCOUNTS_TBL]) })
    .when('/accounts/:itemId/edit', {templateUrl: '/partials/accounts/form.html', controller: 'AccountsFormController', resolve: resolveDb([Database.ACCOUNTS_TBL]) })
    .when('/accounts/:itemId', {templateUrl: '/partials/accounts/show.html', controller: 'AccountsShowController', resolve: resolveDb([Database.ACCOUNTS_TBL]) })

    .when('/line_items/new', {templateUrl: '/partials/line_items/form.html', controller: 'LineItemsFormController', resolve: resolveDb([Database.LINE_ITEMS_TBL, Database.ACCOUNTS_TBL]) })
    .when('/line_items/:itemId/edit', {templateUrl: '/partials/line_items/form.html', controller: 'LineItemsFormController', resolve: resolveDb([Database.LINE_ITEMS_TBL, Database.ACCOUNTS_TBL]) })
    .when('/line_items/:itemId', {templateUrl: '/partials/line_items/show.html', controller: 'LineItemShowController', resolve: resolveDb([Database.LINE_ITEMS_TBL, Database.ACCOUNTS_TBL]) })
    .when('/line_items/:year/:month', {templateUrl: '/partials/line_items/index.html', controller: 'LineItemsIndexController', reloadOnSearch: false, resolve: resolveDb([Database.LINE_ITEMS_TBL, Database.ACCOUNTS_TBL]) })
    .when('/line_items/', {templateUrl: '/partials/line_items/index.html', controller: 'LineItemsIndexController', resolve: resolveDb([Database.LINE_ITEMS_TBL]) })

    .when('/categories/', {templateUrl: '/partials/misc/categories.html'})
    .when('/payees/', {templateUrl: '/partials/misc/payees.html'})
    .when('/batch_assign/', {templateUrl: '/partials/misc/batch_assign.html'})

    .when('/processing_rules/', {templateUrl: '/partials/processing_rules/index.html'})
    .when('/processing_rules/:itemId/edit', {templateUrl: '/partials/processing_rules/form.html'})
    .when('/processing_rules/:itemId', {templateUrl: '/partials/processing_rules/show.html'})
    
    .when('/budgets/:year?', {templateUrl: '/partials/budgets/index.html', controller: 'BudgetsIndexController', resolve: resolveDb([Database.BUDGET_ITEMS_TBL, Database.LINE_ITEMS_TBL]) })
    .when('/budgets/:year/:itemId', {templateUrl: '/partials/budgets/show.html'})
    .when('/budgets/:year/:itemId/edit', {templateUrl: '/partials/budgets/form.html', controller: 'BudgetItemsFormController', resolve: resolveDb([Database.BUDGET_ITEMS_TBL]) })

    .when('/planned_items/:year?', {templateUrl: '/partials/planned_items/index.html'})
    .when('/planned_items/:year/:name/edit', {templateUrl: '/partials/planned_items/edit.html'})

    .when('/reports/:year?/:month?', {templateUrl: '/partials/reports/index.html'})
    .when('/reports/:year/categories/:item', {templateUrl: '/partials/reports/show.html'})

    .when('/import', {templateUrl: '/partials/misc/import.html'})    

    .when('/login_success', redirectTo: '/welcome/')
    .when('/login', {templateUrl: '/partials/user/login.html', controller: 'UserController'})
    .when('/register', {templateUrl: '/partials/user/register.html'})
    .when('/edit_profile', {templateUrl: '/partials/user/edit_profile.html'})

    # download backup

    # memories
    .when('/memories/new', {templateUrl: '/partials/memories/form.html', controller: 'MemoriesFormController', resolve: resolveDb(memoryNgAllDb) })
    .when('/memories/:itemId/edit', {templateUrl: '/partials/memories/form.html', controller: 'MemoriesFormController', resolve: resolveDb(memoryNgAllDb) })
    .when('/memories/:year/:month', {templateUrl: '/partials/memories/index.html', controller: 'MemoriesIndexController', reloadOnSearch: false, resolve: resolveDb(memoryNgAllDb) })
    .when('/memories/:itemId', {templateUrl: '/partials/memories/show.html', controller: 'MemoriesShowController', resolve: resolveDb(memoryNgAllDb) })
    .when('/memories/', {templateUrl: '/partials/memories/index.html', controller: 'MemoriesIndexController', reloadOnSearch: false, resolve: resolveDb(memoryNgAllDb) })

    .when('/events/new', {templateUrl: '/partials/events/form.html', controller: 'EventsFormController', resolve: resolveDb(memoryNgAllDb) })
    .when('/events/:itemId/edit', {templateUrl: '/partials/events/form.html', controller: 'EventsFormController', resolve: resolveDb(memoryNgAllDb) })
    .when('/events/:year/:month', {templateUrl: '/partials/events/index.html', controller: 'EventsIndexController', reloadOnSearch: false, resolve: resolveDb(memoryNgAllDb) })
    .when('/events/:itemId', {templateUrl: '/partials/events/show.html', controller: 'EventsShowController', resolve: resolveDb(memoryNgAllDb) })
    .when('/events/', {templateUrl: '/partials/events/index.html', controller: 'EventsIndexController', reloadOnSearch: false, resolve: resolveDb(memoryNgAllDb) })

    .when('/people/new', {templateUrl: '/partials/people/form.html', controller: 'PeopleFormController', resolve: resolveDb(memoryNgAllDb) })
    .when('/people/:itemId/edit', {templateUrl: '/partials/people/form.html', controller: 'PeopleFormController', resolve: resolveDb(memoryNgAllDb) })
    .when('/people/', {templateUrl: '/partials/people/index.html', controller: 'PeopleIndexController', reloadOnSearch: false, resolve: resolveDb(memoryNgAllDb) })
    .when('/people/:itemId', {templateUrl: '/partials/people/show.html', controller: 'PeopleShowController', resolve: resolveDb(memoryNgAllDb) })


    # Catch all
    .otherwise({redirectTo: '/'})

  # Without server side support html5 must be disabled.
  $locationProvider.html5Mode(true)

App.run ($rootScope, $location) ->
  $rootScope.$on "$routeChangeError", (event, current, previous, rejection) ->
    if rejection.status == 403 && rejection.data.reason == 'not_logged_in'
      $location.path '/login'

angular.module('app.controllers', ['app.services'])