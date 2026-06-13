// Test runner entry point. Add a `runXxxTests(t)` call here for each new test group.
let t = TestRunner()

runTodoItemTests(t)
runTaskStoreTests(t)
runTaskSortingTests(t)

t.summarize()
