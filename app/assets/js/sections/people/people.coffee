angular.module('app.controllers')
  .controller 'PeopleIndexController', ($scope, $routeParams, $location, db) ->
    $scope.items = db.people().getAll().toArray()

    return

  .controller 'PeopleFormController', ($scope, $routeParams, $location, db, errorReporter) ->
    updateFunc = null
    if Lazy($location.$$url).endsWith('new')
      $scope.groupNames = ''
      $scope.title = 'New person'
      $scope.item = {}
      updateFunc = db.people().insert
    else
      $scope.title = 'Edit person'
      $scope.item = db.people().findById($routeParams.itemId)
      $scope.categoryNames = db.memoryGraph().getAssociated('personToGroup', $scope.item.id).join(', ')
      updateFunc = db.people().editById

    $scope.onSubmit = ->
      updateFunc($scope.item)
      Lazy($scope.groupNames.split(',')).each (item) ->
        db.memoryGraph().associate('personToGroup', $scope.item.id, item)

      onSuccess = -> $location.path('/people/')
      saveTables = -> db.saveTables([Database.PEOPLE_TBL, Database.MEMORY_GRAPH_TBL])
      saveTables().then(onSuccess, errorReporter.errorCallbackToScope($scope))

  .controller 'PeopleShowController', ($scope, $routeParams, db) ->
    $scope.item = db.people().findById($routeParams.itemId)
    $scope.groups = db.memoryGraph().getAssociated('personToGroup', $scope.item.id).join(', ')