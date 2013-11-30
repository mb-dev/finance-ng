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

    .when('/line_items/', {templateUrl: '/partials/line_items/index.html'})
    .when('/line_items/new', {templateUrl: '/partials/line_items/form.html', controller: 'LineItemsFormController'})
    .when('/line_items/:line_item_id/edit', {templateUrl: '/partials/line_items/form.html', controller: 'LineItemsFormController'})
    .when('/line_items/:line_item_id', {templateUrl: '/partials/line_items/show.html'})

    .when('/categories/', {templateUrl: '/partials/misc/categories.html'})
    .when('/payees/', {templateUrl: '/partials/misc/payees.html'})
    .when('/batch_assign/', {templateUrl: '/partials/misc/batch_assign.html'})

    .when('/processing_rules/', {templateUrl: '/partials/processing_rules/index.html'})
    .when('/processing_rules/:rule_id/edit', {templateUrl: '/partials/processing_rules/form.html'})
    .when('/processing_rules/:rule_id', {templateUrl: '/partials/processing_rules/show.html'})
    
    .when('/budgets/:year?', {templateUrl: '/partials/budgets/index.html'})
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

angular.module('app.controllers', []).controller('LineItemsIndexController', [
  '$scope', '$route'
  ($scope, $route) ->


])

angular.module('app.controllers', []).controller('LineItemsFormController', [
  '$scope', '$location', 
  ($scope, $location) ->
    $scope.onSubmit = ->
      $location.path('/line_items/')
])

angular.module('app.filters', [])


angular.module('app.services', []).factory('finance-db', )

angular.module('app.directives', [
  'app.services'
])