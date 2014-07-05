root = {}
root.db = null
root.env = 'ci'
root.$q = {}
root.$http = {}
root.$sessionStorage = {}
root.fdb = null

makeObject = (id, value) ->
  result = {}
  result[id] = value
  result

describe 'fdb - line items', ->
  beforeEach(module('app'))
  beforeEach(inject((_$rootScope_, $q, fdb) ->
    root.$q = $q
    root.fdb = fdb
  ))
  it 'should allow adding line items', ->
    db = root.fdb
    db.lineItems().insert { accountId: 1, event_date: moment('2012-10-01').valueOf(), amount: 20, category: 'Groceries', payee: 'Hapoalim' }
    expect(db.lineItems().length()).toEqual(1)

  describe 'have some items', ->
    beforeEach ->
      root.db = root.fdb
      root.db.lineItems().insert { type: 1, accountId: 1, date: moment('2012-10-01').valueOf(), amount: 20, category: 'Groceries', payee: 'Hapoalim' }
      root.item1Id = root.db.lineItems().lastInsertedId
      root.db.lineItems().insert { type: 1, accountId: 1, date: moment('2012-11-01').valueOf(), amount: 30, category: 'Groceries', payee: 'Leumi' }
      root.item2Id = root.db.lineItems().lastInsertedId

    it 'should update actions log', ->
      expect(root.db.lineItems().actionsLog.length).toEqual(2)

    it 'should update the index', ->
      expect(root.db.lineItems().idIndex[root.item1Id]).toEqual(0)
      expect(root.db.lineItems().idIndex[root.item2Id]).toEqual(1)

    it 'should find item', ->
      expect(root.db.lineItems().findById(root.item1Id).category).toEqual('Groceries')

    it 'should find multiple items', ->
      results = root.db.lineItems().findByIds([root.item1Id, root.item1Id])
      expect(results.length).toEqual(2)      

    it 'should delete an item', ->
      expect(root.db.lineItems().length()).toEqual(2)
      root.db.lineItems().deleteById(root.item1Id)
      expect(root.db.lineItems().length()).toEqual(1)

      expect(root.db.lineItems().idIndex).toEqual(makeObject(root.item2Id, 0))
      expect(root.db.lineItems().actionsLog[2]).toEqual({action: 'delete', id: root.item1Id})

    it 'should return items by month', ->
      expect(root.db.lineItems().getItemsByMonthYear(10, 2012).toArray().length).toEqual(1)

    it 'custom functions should work properly', ->
      lineItem = root.db.lineItems().findById(root.item1Id)
      expect(lineItem.$isExpense()).toEqual(true)
      expect(lineItem.$signedAmount()).toEqual(-20)

    it 'should allow rebalance of one item', ->
      root.db.lineItems().insert { type: 1, accountId: 1, date: moment('2012-11-01').valueOf(), amount: 30, category: 'Groceries', payee: 'Leumi', tags: ['Cash'] }
      root.item3Id = root.db.lineItems().lastInsertedId

      item = root.db.lineItems().findById(root.item1Id)
      item.amount = '30'
      root.db.lineItems().editById(item)
      root.db.lineItems().reBalance(item)
      expect(root.db.lineItems().findById(root.item1Id).balance).toEqual('-30')
      expect(root.db.lineItems().findById(root.item2Id).balance).toEqual('-60')
      item = root.db.lineItems().findById(root.item2Id)
      item.amount = '60'
      root.db.lineItems().editById(item)
      root.db.lineItems().reBalance(item)
      expect(root.db.lineItems().findById(root.item1Id).balance).toEqual('-30')
      expect(root.db.lineItems().findById(root.item2Id).balance).toEqual('-90')
      expect(root.db.lineItems().findById(root.item3Id).balance).toEqual('-90')