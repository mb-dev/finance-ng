angular.module('app.controllers')

  .controller 'AccountsFormController', ($scope, $routeParams, $location, db, errorReporter) ->
    updateFunc = null
    $scope.importFormats = {ChaseCC: 'Chase Credit Card', ProvidentVisa: 'Provident Visa', ProvidentChecking: 'Provident Checking', Scottrade: 'Scottrade'}

    if $location.$$url.indexOf('new') > 0
      $scope.title = 'New account'
      $scope.item = {importFormat: Object.keys($scope.importFormats)[0]}
      updateFunc = db.accounts().insert
    else
      $scope.title = 'Edit account'
      $scope.item = db.accounts().findById($routeParams.itemId)
      updateFunc = db.accounts().updateById

    $scope.onSubmit = ->
      onSuccess = -> $location.path('/')
      saveTables = -> db.saveTables([db.tables.accounts])
      updateFunc($scope.item).then(saveTables).then(onSuccess, errorReporter.errorCallbackToScope($scope))

  .controller 'AccountsShowController', ($scope, $routeParams, db) ->
    $scope.item = db.preloaded.item
