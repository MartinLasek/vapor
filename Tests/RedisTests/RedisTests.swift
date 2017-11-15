import XCTest
import Dispatch
import Async
import TCP
import Core
@testable import Redis

class RedisTests: XCTestCase {
    static let allTests = [
        ("testCRUD", testCRUD),
        ("testPubSub", testPubSub),
        ("testPipeline", testPipeline),
    ]
    
    var clientCount = 0
    
    func makeClient() throws -> RedisClient<TCPClient> {
        let queue = DispatchQueue(label: "test.kaas.\(clientCount)")
        clientCount += 1
        
        return try RedisClient<TCPClient>.connect(hostname: "localhost", worker: Worker(queue: queue)).blockingAwait(timeout: .seconds(1))
    }
    
    func testCRUD() throws {
        let connection = try makeClient()
        
        _ = try connection.delete(keys: ["*"]).blockingAwait(timeout: .seconds(1))
        
        let result = try connection.set("world", forKey: "hello").flatMap {
            return connection.getData(forKey: "hello")
        }.blockingAwait(timeout: .seconds(1))
        
        let removedCount = try connection.delete(keys: ["hello"]).blockingAwait(timeout: .seconds(1))
        
        XCTAssertEqual(removedCount, 1)
        
        XCTAssertEqual(result.string, "world")
    }
    
    func testPubSub() throws {
        let promise = Promise<RedisData>()
        
        let listener = try makeClient()
        
        listener.subscribe(to: ["test", "test2"]).drain { data in
            promise.complete(data.message)
        }
        
        let publisher = try makeClient()
        let listeners = try publisher.publish("hello", to: "test").blockingAwait(timeout: .seconds(1))
        
        XCTAssertEqual(listeners, 1)
        
        let result = try promise.future.blockingAwait(timeout: .seconds(3))
        
        XCTAssertEqual(result.string, "hello")
        
        // Prevent deallocation
        XCTAssert(listener.socket.socket.isConnected)
    }
    
    func testPipeline() throws {
        let connection = try makeClient()
        _ = try connection.delete(keys: ["*"]).blockingAwait(timeout: .seconds(1))
        
        let pipeline = connection.makePipeline()
        
        let result = try pipeline
            .enqueue(command: "SET", arguments: [.bulkString("hello"), .bulkString("world")])
            .enqueue(command: "SET", arguments: [.bulkString("hello1"), .bulkString("world")])
            .execute()
            .blockingAwait(timeout: .seconds(1))
        
        
        XCTAssertEqual(result[0].string, "+OK\r")
        XCTAssertEqual(result[1].string, "+OK\r")
        
        
        let deleted = try pipeline
            .enqueue(command: "DEL", arguments: [.bulkString("hello")])
            .enqueue(command: "DEL", arguments: [.bulkString("hello1")])
            .execute()
            .blockingAwait(timeout: .seconds(1))
        
        XCTAssertEqual(deleted[0].int, 1)
        XCTAssertEqual(deleted[1].int, 1)
    }
    
    
}
