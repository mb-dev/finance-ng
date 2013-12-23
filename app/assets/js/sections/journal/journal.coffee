angular.module('app.controllers')
  .controller 'JournalIndexController', ($scope, $routeParams, $location, db) ->
    memories = db.memories().getAllParentMemories().map((item) -> {type: 'memories', modifiedAt: item.modifiedAt, data: item, date: moment(item.modifiedAt).format('L')})
    events = db.events().getAll().map((item) -> {type: 'events', modifiedAt: item.modifiedAt, data: item, date: moment(item.modifiedAt).format('L')})

    allItems = memories.concat(events).sortBy((item) -> item.modifiedAt).reverse()
    $scope.dates = allItems.map((item) -> item.date).uniq().toArray()
    $scope.items = allItems.groupBy((item) -> item.date).toObject()

    return