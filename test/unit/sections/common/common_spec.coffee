root = {}
root.db = null
root.env = 'ci'
root.$q = {}
root.$http = {}
root.$sessionStorage = {}
root.fdb = null

describe 'line items', ->
  beforeEach(module('app'))
  beforeEach(inject((_$rootScope_, $q, fdb) ->
    root.$q = $q
    root.fdb = fdb
  ))
  it 'should allow adding line items', ->
    db = root.fdb
    db.lineItems().insert { event_date: moment('2012-10-01').valueOf(), amount: 20, category: 'Groceries', payee: 'Hapoalim' }
    expect(db.lineItems().length()).toEqual(1)

  describe 'have some items', ->
    beforeEach ->
      root.db = root.fdb
      root.db.lineItems().insert { type: 1, event_date: moment('2012-10-01').valueOf(), amount: 20, category: 'Groceries', payee: 'Hapoalim' }
      root.item1Id = root.db.lineItems().lastInsertedId
      root.db.lineItems().insert { type: 1, event_date: moment('2012-11-01').valueOf(), amount: 30, category: 'Groceries', payee: 'Leumi' }
      root.item2Id = root.db.lineItems().lastInsertedId

    it 'should find item', ->
      expect(root.db.lineItems().findById(root.item1Id).category).toEqual('Groceries')

    it 'should delete an item', ->
      expect(root.db.lineItems().length()).toEqual(2)
      root.db.lineItems().removeById(root.item1Id)
      expect(root.db.lineItems().length()).toEqual(1)

    it 'should return items by month', ->
      expect(root.db.lineItems().getItemsByMonthYear(10, 2012).toArray().length).toEqual(1)

    it 'custom functions should work properly', ->
      lineItem = root.db.lineItems().findById(root.item1Id)
      expect(lineItem.$isExpense()).toEqual(true)
      expect(lineItem.$signedAmount()).toEqual(-20)
