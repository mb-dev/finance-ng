root = {}
root.db = null
root.env = 'ci'

describe 'line items', ->

  it 'should allow adding line items', ->
    db = new Database()
    db.lineItems().insert { date: moment().unix(), amount: 20, category: 'Groceries', payee: 'Hapoalim' }
    expect(db.lineItems().length()).toEqual(1)

  describe 'have some items', ->
    beforeEach ->
      root.db = new Database()
      root.item1Id = root.db.lineItems().insert { date: moment().unix(), amount: 20, category: 'Groceries', payee: 'Hapoalim' }
      root.item2Id = root.db.lineItems().insert { date: moment().unix(), amount: 30, category: 'Groceries', payee: 'Leumi' }

    it 'should find item', ->
      expect(root.db.lineItems().findById(root.item1Id).category).toEqual('Groceries')

    it 'should delete an item', ->
      expect(root.db.lineItems().length()).toEqual(2)
      root.db.lineItems().removeById(root.item1Id)
      expect(root.db.lineItems().length()).toEqual(1)
