root = {}

describe 'budget report view', ->
  beforeEach ->
    root.budgetItem = {name: 'Groceries', budget_year: 2012, categories: ['Groceries'] }

    db = new Database
    db.lineItems().insert {type: 1, event_date: moment('2012-01-01').valueOf(), amount: '20.0', category_name: 'Groceries'}
    db.lineItems().insert {type: 0, event_date: moment('2012-01-02').valueOf(), amount: '10.0', category_name: 'Groceries'}
    db.lineItems().insert {type: 1, event_date: moment('2012-01-03').valueOf(), amount: '30.0', category_name: 'Hobbies::Travel', grouped_label: 'USA Trip'}
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