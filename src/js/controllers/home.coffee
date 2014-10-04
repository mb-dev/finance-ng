angular.module('app.controllers')
  .controller 'WelcomePageController', ($scope, $routeParams, $location, db) ->
    if db
      $scope.accounts = db.preloaded.accounts
      db.lineItems().balancesByAccount().then (balances) -> $scope.$apply ->
        $scope.balances = balances
    

