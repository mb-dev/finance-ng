angular.module('app.controllers')
  .controller 'JournalIndexController', ($scope, $routeParams, $location, db) ->
    memories = db.memories().getAllParentMemories().map((item) -> {type: 'memories', modifiedAt: item.modifiedAt, data: item, date: item.date})
    events = db.events().getAll().map((item) -> {type: 'events', modifiedAt: item.modifiedAt, data: item, date: item.date})

    allItems = memories.concat(events).sortBy((item) -> item.date).reverse()
    $scope.dates = allItems.sortBy((item) -> item.date).reverse().map((item) -> moment(item.date).format('L')).uniq().toArray()
    $scope.items = allItems.groupBy((item) -> moment(item.date).format('L')).toObject()

    return