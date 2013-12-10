root = {}
root.db = null
root.env = 'ci'

describe 'line items', ->

  it 'should allow adding line items', ->
    db = new Database()
    db.lineItems().insert { event_date: moment('2012-10-01').valueOf(), amount: 20, category: 'Groceries', payee: 'Hapoalim' }
    expect(db.lineItems().length()).toEqual(1)

  describe 'have some items', ->
    beforeEach ->
      root.db = new Database()
      root.item1Id = root.db.lineItems().insert { type: 1, event_date: moment('2012-10-01').valueOf(), amount: 20, category: 'Groceries', payee: 'Hapoalim' }
      root.item2Id = root.db.lineItems().insert { type: 1, event_date: moment('2012-11-01').valueOf(), amount: 30, category: 'Groceries', payee: 'Leumi' }

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

describe 'Box', ->
  it 'should allow setting values', ->
    item = {name: 'Groceries'}
    box = new Box()
    box.addRow(item)
    box.setColumns([0..11], ['expense', 'future_expense', 'planned_expense'])
    box.addToValue(item, 0, 'expense', 100)
    box.addToValue(item, 1, 'expense', 100)

    firstColumnValue = box.rowColumnValues(item)[0]
    expect(firstColumnValue.column).toEqual('0')
    expect(firstColumnValue.values.expense.toFixed(0)).toEqual('100')

    totals = box.rowTotals(item)
    expect(totals['expense'].toFixed(0)).toEqual('200')