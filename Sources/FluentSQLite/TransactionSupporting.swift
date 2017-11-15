import Async
import Fluent
import SQLite

extension SQLiteConnection: TransactionSupporting {
    /// See TransactionExecutor.execute
    public func execute(transaction: DatabaseTransaction<SQLiteConnection>) -> Future<Void> {
        let promise = Promise(Void.self)

        query(string: "BEGIN TRANSACTION").execute().do {
            transaction.run(on: self).do {
                print("transaction done")
                self.query(string: "COMMIT TRANSACTION")
                    .execute()
                    .chain(to: promise)
            }.catch { err in
                self.query(string: "ROLLBACK TRANSACTION").execute().do { query in
                    // still fail even tho rollback succeeded
                    promise.fail(err)
                }.catch { err in
                    print("Rollback failed") // fixme: combine errors here
                    promise.fail(err)
                }
            }
        }.catch(promise.fail)

        return promise.future
    }
}
