angular.module('app.controllers')
  .controller 'WelcomePageController', ($scope, $routeParams, $location, db) ->
    if db
      $scope.accounts = db.accounts().getAll().toArray()
      $scope.balances = db.lineItems().balancesByAccount()
    

