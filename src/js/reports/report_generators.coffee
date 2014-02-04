class window.LineItemsReportView
  constructor: (db, year) ->
    @db = db
    @year = year
    
    @lineItems = db.lineItems().getByDynamicFilter({date: {year: @year}}).toArray()    

    rootCategoriesMap = {}
    @rootCategoryToCategories = {}

    @lineItemsBox = new Box()
    @childCategoriesBox = new Box()
    db.categories().getAll().toArray().forEach (categoryName) =>
      return if categoryName.indexOf('Transfer') >= 0
      rootCategoryName = categoryName.split(':')[0]
      @childCategoriesBox.addRow(categoryName)
      if rootCategoryName == 'Income'
        @lineItemsBox.addRow(categoryName)
        rootCategoriesMap[categoryName] = categoryName
        @rootCategoryToCategories[categoryName] = {categoryName: true}
      else
        @lineItemsBox.addRow(rootCategoryName)
        rootCategoriesMap[categoryName] = rootCategoryName
        @rootCategoryToCategories[rootCategoryName] ||= {}
        @rootCategoryToCategories[rootCategoryName][categoryName] = true

    
    @lineItemsBox.setColumns([0..11], ['amount'])
    @childCategoriesBox.setColumns([0..11], ['amount'])

    @lineItems.forEach (item) =>
      return if item.tags && item.tags.indexOf(LineItemCollection.EXCLUDE_FROM_REPORT) >= 0
      return if !item.categoryName || item.categoryName.indexOf('Transfer') >= 0
      @lineItemsBox.addToValue(rootCategoriesMap[item.categoryName], item.$date().month(), 'amount', item.$signedAmount())
      @childCategoriesBox.addToValue(item.categoryName, item.$date().month(), 'amount', item.$signedAmount())

  generateReport: =>
    incomeSection = {name: 'Income', rootCategories: [], monthlyTotals: [], totalAvg: '0', totalSum: '0'}
    expenseSection = {name: 'Expense', rootCategories: [], monthlyTotals: [], totalAvg: '0', totalSum: '0'}
    reportSections = [incomeSection, expenseSection]

    totalIncome = new BigNumber(0)
    @db.user().config.incomeCategories.forEach (categoryName) =>
      totalIncome = totalIncome.plus(@lineItemsBox.rowTotals(categoryName).amount)
    incomeSection.totalSum = totalIncome
    incomeSection.totalAvg = totalIncome.div(12)
    @db.user().config.incomeCategories.forEach (categoryName) =>
      categoryInfo = {
        name: categoryName
        monthlyTotals: []
        avg: @lineItemsBox.rowTotals(categoryName).amount.div(12).toFixed(2)
        total: @lineItemsBox.rowTotals(categoryName).amount.toFixed(2)
        percent: @lineItemsBox.rowTotals(categoryName).amount.div(totalIncome).times(100).toFixed(0)
        categories: categoryName
      }
      @lineItemsBox.rowColumnValues(categoryName).forEach (incomeColumn) =>
        categoryInfo.monthlyTotals.push({total: incomeColumn.values.amount.toFixed(2) })
        incomeSection.monthlyTotals[incomeColumn.column] = incomeSection.monthlyTotals[incomeColumn.column] || {total: new BigNumber(0)}
        incomeSection.monthlyTotals[incomeColumn.column].total = incomeSection.monthlyTotals[incomeColumn.column].total.plus(incomeColumn.values.amount)
      incomeSection.rootCategories.push(categoryInfo)

    totalExpenses = new BigNumber(0)
    Object.keys(@lineItemsBox.rowByHash).sort().forEach (categoryName) =>
      return if Lazy(categoryName).startsWith('Income')
      totalExpenses = totalExpenses.plus(@lineItemsBox.rowTotals(categoryName).amount.times(-1))
    expenseSection.totalSum = totalExpenses.times(-1)
    expenseSection.totalAvg = totalExpenses.times(-1).div(12)
    Object.keys(@lineItemsBox.rowByHash).sort().forEach (rootCategoryName) =>
      return if Lazy(rootCategoryName).startsWith('Income')
      categoryInfo = {
        name: rootCategoryName
        monthlyTotals: []
        avg: @lineItemsBox.rowTotals(rootCategoryName).amount.times(-1).div(12).toFixed(2)
        total: @lineItemsBox.rowTotals(rootCategoryName).amount.times(-1),
        percent: @lineItemsBox.rowTotals(rootCategoryName).amount.times(-1).div(totalExpenses).times(100).toFixed(0),
        categories: Object.keys(@rootCategoryToCategories[rootCategoryName]).join(',')
        subCategoriesInfo: []
      }
      @lineItemsBox.rowColumnValues(rootCategoryName).forEach (expenseColumn) =>
        categoryInfo.monthlyTotals.push({total: expenseColumn.values.amount.times(-1).toFixed(2) })
        expenseSection.monthlyTotals[expenseColumn.column] = expenseSection.monthlyTotals[expenseColumn.column] || {total: new BigNumber(0)}
        expenseSection.monthlyTotals[expenseColumn.column].total = expenseSection.monthlyTotals[expenseColumn.column].total.plus(expenseColumn.values.amount)
      expenseSection.rootCategories.push(categoryInfo)      
      # calculate sub categories
      Object.keys(@rootCategoryToCategories[rootCategoryName]).forEach (categoryName) =>
        subCategoryInfo = {
          name: categoryName
          monthlyTotals: []
          avg: @childCategoriesBox.rowTotals(categoryName).amount.times(-1).div(12).toFixed(2)
          total: @childCategoriesBox.rowTotals(categoryName).amount.times(-1).toFixed(2),
          percent: @childCategoriesBox.rowTotals(categoryName).amount.times(-1).div(categoryInfo.total).times(100).toFixed(0),
        }
        @childCategoriesBox.rowColumnValues(categoryName).forEach (expenseColumn) =>
          subCategoryInfo.monthlyTotals.push({total: expenseColumn.values.amount.times(-1).toFixed(2) })
        categoryInfo.subCategoriesInfo.push(subCategoryInfo)     

    # calculate total
    reportTotals = {monthly: []}
    totalAmount = new BigNumber(0)
    [0..11].forEach (month) =>
      if expenseSection.monthlyTotals[month]
        reportTotals.monthly[month] = incomeSection.monthlyTotals[month].total.plus(expenseSection.monthlyTotals[month].total)
      else
        reportTotals.monthly[month] = new BigNumber(0)
      totalAmount = totalAmount.plus(reportTotals.monthly[month])
    reportTotals.avg = totalAmount.div(12)
    reportTotals.sum = totalAmount
    reportTotals.percent = totalAmount.div(totalIncome).times(100).toFixed(0)
    {reportSections: reportSections, reportTotals: reportTotals}


class window.BudgetReportView
  constructor: (db, year) ->
    @db = db
    @year = parseInt(year, 10)

    @budgetItems = db.budgetItems().getItemsByYear('budgetYear', @year).toArray()
    @plannedItems = db.plannedItems().getItemsByYear('eventDateStart', @year).toArray()
    @lineItems = db.lineItems().getItemsByYear('date', @year).toArray()

    @totals = {}

    @groupedItems = {}
    Lazy(@lineItems).each (lineItem) =>
      if lineItem.grouped_label
        item = @groupedItems[lineItem.grouped_label] ?= {amount: 0, month: 12, label: lineItem.grouped_label}
        item['amount'] += lineItem.$signedAmount()
        item['month'] = Lazy([item['month'], lineItem.$date().month]).min
    
    @groupedItems = Lazy(@groupedItems).values().sortBy((item) -> item['month']).toArray()

    categoryToBudget = {}
    Lazy(@budgetItems).each (budgetItem) ->
      Lazy(budgetItem.categories).each (categoryName) ->
        categoryToBudget[categoryName] = budgetItem

    # prepare expense box
    @expenseBox = new Box()
    Lazy(@budgetItems).each (budgetItem) =>
      @expenseBox.addRow(budgetItem.name)
    
    @expenseBox.setColumns([0..11], ['expense', 'future_expense', 'planned_expense'])
    # prepare income box
    @incomeBox = new Box()
    @incomeBox.addRow('income')
    @incomeBox.setColumns([0..11], ['amount', 'future_income'])
    @groups = {}
    @unbudgetedCategories = []
    # add expenses/income
    Lazy(@lineItems).each (lineItem) =>
      return if lineItem.tags && lineItem.tags.indexOf(LineItemCollection.EXCLUDE_FROM_REPORT) >= 0
      return if lineItem.categoryName == LineItemCollection.TRANSFER_TO_CASH
      if db.user().config.incomeCategories.indexOf(lineItem.categoryName) >= 0
        @incomeBox.addToValue('income', lineItem.$date().month(), 'amount', lineItem.$signedAmount())
      else if categoryToBudget[lineItem.categoryName]
        @expenseBox.addToValue(categoryToBudget[lineItem.categoryName].name, lineItem.$date().month(), 'expense', lineItem.$signedAmount())
      else if typeof(lineItem.categoryName) == 'undefined'
        @unbudgetedCategories.push('empty')
      else if lineItem.categoryName? && lineItem.categoryName.length == 0
        @unbudgetedCategories.push('empty')
      else
        @unbudgetedCategories.push(lineItem.categoryName)
      if lineItem.groupedLabel
        @groups[lineItem.groupedLabel] ||= {groupedLabel: lineItem.groupedLabel, amount: new BigNumber(0), firstDate: lineItem.date, lastDate: lineItem.date}
        @groups[lineItem.groupedLabel].amount = @groups[lineItem.groupedLabel].amount.plus(lineItem.$signedAmount())
        if lineItem.date < @groups[lineItem.groupedLabel].firstDate
          @groups[lineItem.groupedLabel].firstDate = lineItem.date
        else if lineItem.date > @groups[lineItem.groupedLabel].lastDate
          @groups[lineItem.groupedLabel].lastDate = lineItem.date

    # add future expenses
    if @year == moment().year()
      currentMonth = moment().month()
      Lazy(@budgetItems).each (budgetItem) =>
        Lazy.range(currentMonth, 11, 1).each (futureMonth) =>
          @expenseBox.addToValue(budgetItem.name, futureMonth, 'future_expense', budgetItem.estimatedMinMonthly)
        
      # add planned items
      # Lazy(@plannedItems).each (plannedItem) =>
      #   currentMonth = moment().month()
      #   Lazy([plannedItem.$eventDateStart.month()..plannedItem.$eventDateEnd()]).each (month) ->
      #     if month > currentMonth
      #       if planned_item.$isIncome()
      #         @incomeBox.addToValue('income', month, 'future_income', plannedItem.amount)
      #       else
      #         @expenseBox.addToValue(categoryToBudget[plannedItem.category_name].name, month, 'planned_expense', plannedItem.amount)



  isInFuture: (month) =>
    month > moment().month() && @year == moment().year()
  
  totalIncome: =>
    @incomeBox.rowTotals('income').amount.plus(@incomeBox.rowTotals('income').future_income)

  totalExpensesForBudgetItemInYear: (budgetItem) ->
    @expenseBox.rowTotals(budgetItem.name).expense.abs().plus(@expenseBox.rowTotals(budgetItem.name).future_expense.plus(@expenseBox.rowTotals(budgetItem.name).planned_expense))
  
  percentExpense: (budgetItem) ->
    return 'N/A' if @totalIncome().equals(0)
    ((@totalExpensesForBudgetItemInYear(budgetItem).div(@totalIncome())).times(100)).toFixed(0) + '%'

  
  generateReport: =>
    incomeRow = []
    Lazy(@incomeBox.rowColumnValues('income')).each (column) =>
      month = column.column
      if @isInFuture(month)
        incomeRow.push {type: 'future', amount: column.values.future_income.toFixed(2)}
      else
        incomeRow.push {type: 'current', amount: column.values.amount.toFixed(2) }

    expenseRowsForBudgetItem = []
    Lazy(@budgetItems).sortBy((item) -> item.name).each (budgetItem) =>
      expenseRow = {columns: []}
      expenseRow.meta = {
        budgetItemId: budgetItem.id
        name: budgetItem.name 
        limit: budgetItem.limit
        categories: budgetItem.categories.join(',')
        now: 0
        total: budgetItem.limit*12
        expenses: @totalExpensesForBudgetItemInYear(budgetItem).toFixed(2) 
        percent: @percentExpense(budgetItem)
      }
      amountAvailable = 0
      amountUsed = BigNumber(0)
      Lazy(@expenseBox.rowColumnValues(budgetItem.name)).each (expenseColumn) =>
        month = expenseColumn.column
        if expenseColumn.values.expense != 0
          amount = expenseColumn.values.expense.abs()
          expenseRow.columns.push {type: 'current', amount: amount.toFixed(2)}
          amountAvailable += budgetItem.limit
          amountUsed = amountUsed.plus(expenseColumn.values.expense.times(-1))
        else if expenseColumn.values.planned_expense > 0
          expenseRow.columns.push {type: 'planned', amount: expenseColumn.values.planned_expense.toFixed(2)}
        else if expenseColumn.values.future_expense > 0
          expenseRow.columns.push {type: 'future', amount: expenseColumn.values.future_expense.toFixed(2)}
        else
          expenseRow.columns.push {type: 'other', amount: '0.0'}
      
      expenseRow.meta.now = BigNumber(amountAvailable).minus(amountUsed).toFixed(2)

      expenseRowsForBudgetItem.push expenseRow

    totalLimit = Lazy(@budgetItems).pluck('limit').sum()
    {
      incomeMeta: {totalIncome: @totalIncome().toFixed(2)}, 
      incomeCategories: @db.user().config.incomeCategories.join(','),
      incomeRow: incomeRow, 
      expenseRows: expenseRowsForBudgetItem, 
      totalBudgeted: totalLimit,
      groups: Lazy(@groups).values().toArray()
      unbudgetedCategories: Lazy(@unbudgetedCategories).uniq().toArray()
    }

#   def budget_year_range
#     (BudgetItem.min(:budget_year).to_i)..(BudgetItem.max(:budget_year).to_i)
#   end

#   def budget_items
#     @budget_items
#   end

#   def grouped_item_label(grouped_item)
#     item = grouped_item
#     "#{grouped_item[:label]} (#{Date.new(@active_year, item[:month]).strftime('%B')}): Total: #{item[:amount]*-1}"
#   end



#   def future_amount(budget_item)
#     @totals[budget_item.name] ||= 0
#     @totals[budget_item.name] -= budget_item.estimated_min_monthly_amount

#     budget_item.estimated_min_monthly_amount
#   end

#   def future_income(month)
#     found_income = current_user.planned_items.where(:event_date_begin.gt => Date.new(@active_year, month, 1), :event_date_end.lt => Date.new(@active_year, month, 1).end_of_month ).first
#     income_for_month = found_income ? found_income.amount : 0
#     @totals['Income'] ||= 0
#     @totals['Income'] += income_for_month
#     income_for_month
#   end

#   def planned_amount(budget_item, month)

#   end

#   def total_expenses_for_budget_item_in_month(budget_item, month)
#     #noinspection RubyArgCount
#     current_date = Date.new(@active_year, month, 1)
#     amount = LineItem.inline_sum_with_filters(@current_user, @line_items, {
#                                               :categories => budget_item.categories,
#                                               :in_month_of_date => current_date
#                                               }, LineItemReportProcess.new)

#     @totals[budget_item.name] ||= 0
#     @totals[budget_item.name] += amount
#     amount * -1
#   end

#   def total_expenses_for_budget_item_in_year(budget_item)
#     @expenseBox.row_totals(budget_item)[:expense]*-1 +
#             @expenseBox.row_totals(budget_item)[:future_expense] +
#             @expenseBox.row_totals(budget_item)[:planned_expense]
#   end

#   def amount_left_budget_item_in_year(budget_item)
#     budget_item.limit.to_i.to_f * 12 - total_expenses_for_budget_item_in_year(budget_item)

#   end

#   def total_limit
#     @budget_items.collect(&:limit).compact.sum
#   end

#   def income_at(month)
#     income_for_month = @line_items.select { |li| li.event_date.month == month and LineItem::INCOME_CATEGORIES.include? li.category_name }.sum(&:signed_amount)
#     @totals['Income'] ||= 0
#     @totals['Income'] += income_for_month
#     income_for_month
#   end



#   def percent_expense(budget_item)
#     ((total_expenses_for_budget_item_in_year(budget_item).to_f / total_income.to_f) * 100).to_i.to_s + '%'
#   end

#   def amount_available_now(budget_item)
#     return 'N/A' if Time.now.year != @active_year
#     expenses_so_far = 0
#     (1..Time.now.month).each do |month|
#       expenses_so_far += expenseBox.row_column_values(budget_item)[month - 1][1][:expense]
#     end
#     (budget_item.limit * Time.now.month) - (expenses_so_far*-1)
#   end
# # end