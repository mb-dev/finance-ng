root = {}
root.$q = {}
root.$http = {}
root.$sessionStorage = {}

describe 'budget report view', ->
  beforeEach(module('app'))
  beforeEach(inject((_$rootScope_, $q, fdb) ->
    root.$q = $q
    root.fdb = fdb
  ))
  beforeEach ->
    root.budgetItem = {name: 'Groceries', budgetYear: 2012, categories: ['Groceries'] }

    db = root.fdb
    db.lineItems().insert {type: 1, date: moment('2012-01-01').valueOf(), amount: '20.0', categoryName: 'Groceries'}
    db.lineItems().insert {type: 0, date: moment('2012-01-02').valueOf(), amount: '10.0', categoryName: 'Groceries'}
    db.lineItems().insert {type: 1, date: moment('2012-01-03').valueOf(), amount: '30.0', categoryName: 'Hobbies::Travel', groupedLabel: 'USA Trip'}
    db.budgetItems().insert root.budgetItem
    root.budgetView = new BudgetReportView(db, 2012)

  it 'should construct a report properly', ->
    januaryBudgetBox = root.budgetView.expenseBox.rowColumnValues(root.budgetItem.name)[0]
    expect(januaryBudgetBox.column).toEqual('0')
    expect(januaryBudgetBox.values.expense.toFixed(0)).toEqual('-10')

  it 'should also generate report', ->
    result = root.budgetView.generateReport()
    expect(result.incomeRow[0].amount).toEqual('0.00')
    expect(result.expenseRows[0].meta.name).toEqual('Groceries')
    expect(result.expenseRows[0].columns[0].amount).toEqual('10.00')