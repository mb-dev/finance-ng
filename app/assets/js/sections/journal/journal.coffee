angular.module('app.controllers')
  .controller 'JournalIndexController', ($scope, $routeParams, $location, db) ->
    $scope.currentDate = moment()
    if $routeParams.month? && $routeParams.year?
      $scope.currentDate.year(+$routeParams.year).month(+$routeParams.month - 1)

    memories = db.memories().getByDynamicFilter({date: {month: $scope.currentDate.month(), year: $scope.currentDate.year()}, onlyParents: true}).map((item) -> {type: 'memories', modifiedAt: item.modifiedAt, data: item, date: item.date})
    events = db.events().getItemsByMonthYear($scope.currentDate.month(), $scope.currentDate.year()).map((item) -> {type: 'events', modifiedAt: item.modifiedAt, data: item, date: item.date})

    allItems = memories.concat(events).sortBy((item) -> item.date).reverse()
    $scope.dates = allItems.sortBy((item) -> item.date).reverse().map((item) -> moment(item.date).format('L')).uniq().toArray()
    $scope.items = allItems.groupBy((item) -> moment(item.date).format('L')).toObject()


    $scope.nextMonth = ->
      $scope.currentDate.add('months', 1)
      $location.path('/journal/' + $scope.currentDate.year().toString() + '/' + ($scope.currentDate.month()+1).toString())
    $scope.prevMonth = ->
      $scope.currentDate.add('months', -1)
      $location.path('/journal/' + $scope.currentDate.year().toString() + '/' + ($scope.currentDate.month()+1).toString())
    

    return