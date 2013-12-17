angular.module('app.controllers')
  .controller 'MemoriesIndexController', ($scope, $routeParams, $location, db) ->
    applyDateChanges = ->
      $scope.items = db.memories().getItemsByMonthYear($scope.currentDate.month(), $scope.currentDate.year(), (item) -> item.event_date).toArray()

    $scope.currentDate = moment()
    if $routeParams.month && $routeParams.year
      $scope.currentDate.year(+$routeParams.year).month(+$routeParams.month - 1)

    applyDateChanges()
    $scope.nextMonth = ->
      $scope.currentDate.add('months', 1)
      applyDateChanges()
      $location.path('/memories/' + $scope.currentDate.year().toString() + '/' + ($scope.currentDate.month()+1).toString())
    $scope.prevMonth = ->
      $scope.currentDate.add('months', -1)
      applyDateChanges()
      $location.path('/memories/' + $scope.currentDate.year().toString() + '/' + ($scope.currentDate.month()+1).toString())

    return

  .controller 'MemoriesFormController', ($scope, $routeParams, $location, db, errorReporter) ->
    updateFunc = null
    if Lazy($location.$$url).endsWith('new')
      $scope.categoryNames = ''
      $scope.title = 'New memory'
      $scope.item = {event_date: moment().valueOf()}
      updateFunc = db.memories().insert
    else
      $scope.title = 'Edit memory'
      $scope.item = db.memories().findById($routeParams.itemId)
      $scope.categoryNames = db.memoryGraph().getAssociated('memoryToCategory', $scope.item.id).join(', ')
      updateFunc = db.memories().editById

    $scope.onSubmit = ->
      updateFunc($scope.item)
      Lazy($scope.categoryNames.split(',')).each (item) ->
        db.memoryGraph().associate('memoryToCategory', $scope.item.id, item)

      onSuccess = -> $location.path('/memories/')
      saveTables = -> db.saveTables([Database.MEMORIES_TBL, Database.MEMORY_GRAPH_TBL])
      saveTables().then(onSuccess, errorReporter.errorCallbackToScope($scope))

  .controller 'MemoriesShowController', ($scope, $routeParams, db) ->
    $scope.item = db.memories().findById($routeParams.itemId)
    $scope.categories = db.memoryGraph().getAssociated('memoryToCategory', $scope.item.id).join(', ')