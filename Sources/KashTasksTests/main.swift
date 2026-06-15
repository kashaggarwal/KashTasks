// Test runner entry point. Add a `runXxxTests(t)` call here for each new test group.
let t = TestRunner()

runTodoItemTests(t)
runTaskStoreTests(t)
runTaskSortingTests(t)
runReminderLogicTests(t)
runNotifiedStoreTests(t)
runRecurrenceTests(t)
runTodoItemRecurrenceTests(t)
runTaskStoreMutationTests(t)

t.summarize()
