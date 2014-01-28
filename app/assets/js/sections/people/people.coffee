angular.module('app.controllers')
  .controller 'PeopleIndexController', ($scope, $routeParams, $location, db) ->
    $scope.items = db.people().getAll().groupBy((item) -> item.categories[0]).toObject()
    $scope.categories = Object.keys($scope.items).sort()

    return

  .controller 'PeopleFormController', ($scope, $routeParams, $location, db, errorReporter) ->
    $scope.allCategories = db.categories().getAll().toArray()

    updateFunc = null
    if $location.$$url.indexOf('new') > 0
      $scope.groupNames = ''
      $scope.title = 'New person'
      $scope.item = {}
      updateFunc = db.people().insert
    else
      $scope.title = 'Edit person'
      $scope.item = db.people().findById($routeParams.itemId)
      updateFunc = db.people().editById

    $scope.onSubmit = ->
      updateFunc($scope.item)
      db.categories().findOrCreate($scope.item.categories)
      db.categories().findOrCreate($scope.item.interests)

      onSuccess = -> $location.path($routeParams.returnto || '/people/' + $scope.item.id)
      saveTables = -> db.saveTables([db.tables.people, db.tables.categories])
      saveTables().then(onSuccess, errorReporter.errorCallbackToScope($scope))

  .controller 'PeopleShowController', ($scope, $routeParams, db) ->
    $scope.item = db.people().findById($routeParams.itemId)

    $scope.events = db.events().getEventsByParticipantId($scope.item.id).toArray()
    $scope.memories = db.memories().getMemoriesByPersonId($scope.item.id).toArray()
    $scope.mentionedMemories = $scope.item.$mentioned().getAll().toArray()