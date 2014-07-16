root = {}
describe 'LineItemCollection', ->
  beforeEach(module('app'))
  beforeEach(inject((_$rootScope_, $q, fdb) ->
    root.$q = $q
    root.fdb = fdb
    root.collection = root.fdb.lineItems()
  ))
  describe 'deleteItemAndRebalance', ->
    it 'when there are 4 items, it should delete and rebalance', ->
      item1 = fixtures.models.lineItems.getLineItem({type: LineItemCollection.INCOME, amount: '100'})
      root.collection.insert(item1)
      item2 = fixtures.models.lineItems.getLineItem({amount: '10'})
      root.collection.insert(item2)
      item3 = fixtures.models.lineItems.getLineItem({amount: '20'})
      root.collection.insert(item3)
      item4 = fixtures.models.lineItems.getLineItem({amount: '30'})
      root.collection.insert(item4)
      root.collection.reBalance(item1)
      expect(root.collection.collection.length).toEqual(4) 
      expect(root.collection.collection[3].balance).toEqual('40')
      expect(Lazy(root.collection.actionsLog).pluck('action').toArray()).toEqual(['insert', 'insert', 'insert', 'insert', 'update', 'update', 'update', 'update'])
      root.collection.deleteItemAndRebalance(item3)
      expect(root.collection.collection.length).toEqual(3) 
      expect(root.collection.collection[2].balance).toEqual('60')
      expect(Lazy(root.collection.actionsLog).pluck('action').toArray()).toEqual(['insert', 'insert', 'insert', 'insert', 'update', 'update', 'update', 'update', 'delete', 'update'])

