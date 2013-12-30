angular.module('app.controllers')
  .controller 'AccountsIndexController', ($scope, $route, db) ->
    $scope.accounts = db.accounts().getAll().toArray()
    return

  .controller 'AccountsFormController', ($scope, $routeParams, $location, db, errorReporter) ->
    updateFunc = null
    if Lazy($location.$$url).endsWith('new')
      $scope.title = 'New account'
      $scope.item = {import_format: 'ProvidentChecking'}
      updateFunc = db.accounts().insert
    else
      $scope.title = 'Edit account'
      $scope.item = db.accounts().findById($routeParams.itemId)
      updateFunc = db.accounts().editById

    $scope.importFormats = {ChaseCC: 'Chase CC', ProvidentVisa: 'Provident Visa', ProvidentChecking: 'Provident Checking', Scottrade: 'Scottrade'}

    $scope.onSubmit = ->
      onSuccess = -> $location.path('/accounts/')
      saveTables = -> db.saveTables([db.tables.accounts])
      updateFunc($scope.item).then(saveTables).then(onSuccess, errorReporter.errorCallbackToScope($scope))

  .controller 'AccountsShowController', ($scope, $routeParams, db) ->
    $scope.item = db.accounts().findById($routeParams.itemId)
