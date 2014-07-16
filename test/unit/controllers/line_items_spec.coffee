root = {}
describe 'LineItemsIndexController', ->
  beforeEach(module('app.controllers'))
  beforeEach(inject((_$rootScope_, $q, fdb, $controller, $location) ->
    root.$q = $q
    root.fdb = fdb
    root.collection = root.fdb.lineItems()

    # prepare collection
    item1 = fixtures.models.lineItems.getLineItem({type: LineItemCollection.INCOME, amount: '100'})
    root.collection.insert(item1)

    # prepare controller
    root.scope = {}
    root.controller = $controller('LineItemsIndexController', {
      $scope: root.scope,
      $routeParams: {year: '2014', month: '1'},
      $location: $location,
      db: fdb
    })
  ))
  describe 'initialization', ->
    it 'should load the items', ->
      expect(root.scope.lineItems.length).toEqual(1)
  describe '$scope.deleteItem', ->
    it 'should remove item from the current collection', ->
      defer = root.$q.defer()
      defer.resolve()
      spyOn(root.fdb, 'saveTables').and.returnValue(defer.promise)
      root.scope.deleteItem(root.scope.lineItems[0]).then ->
        expect(root.fdb.saveTables).toHaveBeenCalled()
        expect(root.scope.lineItems.length).toEqual(0)
      
