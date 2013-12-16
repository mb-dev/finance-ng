angular.module('app.controllers')
  .controller 'MemoriesIndexController', ($scope, $routeParams, $location, db) ->
    applyDateChanges = ->
      $scope.memories = db.memories().getItemsByMonthYear($scope.currentDate.month(), $scope.currentDate.year(), (item) -> item.event_date).toArray()

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
      $scope.title = 'New memory'
      $scope.item = {date: moment().format('L'), tags: []}
      updateFunc = db.memories().insert
    else
      $scope.title = 'Edit memory'
      $scope.item = db.memories().findById($routeParams.itemId)
      updateFunc = db.memories().editById
    $scope.memoryCategories = db.memoryCategories().getAll().toArray()
    $scope.categoryName = ''

    $scope.onSubmit = ->
      categoryId = db.memoryCategories().addOrInsertCategoryByName($scope.categoryName)
      updateFunc($scope.item)
      db.memoryGraph().associate('memoryToCategory', $scope.item.id, categoryId)

      onSuccess = -> $location.path('/memories/')
      saveTables = -> db.saveTables([Database.MEMORIES_TBL])
      saveTables().then(onSuccess, errorReporter.errorCallbackToScope($scope))

  .controller 'MemoriesShowController', ($scope, $routeParams, db) ->
    $scope.item = db.memories().findById($routeParams.itemId)
    $scope.categories = db.memoryCategories().findByIds($scope.item.categoryIds)