// Copyright (c) Tailscale Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause


import XCTest
@testable import Tailscale



final class TailscaleTests: XCTestCase {
    var controlURL: String = ""

    override func setUp() async throws {
        if controlURL == "" {
            var buf = [CChar](repeating:0, count: 1024)
            let res = buf.withUnsafeMutableBufferPointer { ptr in
                return run_control(ptr.baseAddress!, 1024)
            }
            controlURL = String(cString: buf)
            if res == 0 {
                print("Started control with url \(controlURL)")
            }
        }
    }

    override func tearDown() async throws {
        stop_control()
    }

    func testV4() async throws {
        try await runConnectionTests(for: .v4)
    }

    func testV6() async throws {
        try await runConnectionTests(for: .v6)
    }

    func runConnectionTests(for netType: IPAddrType) async throws {
        let config = mockConfig()
        let logger = DefaultLogger()

        let want = "Hello Tailscale".data(using: .utf8)!

        do {
            //100.64.0.1?
            let ts1 = try TailscaleNode(config: config, logger: logger)
            try await ts1.up()

            //100.64.0.2?
            let ts2 = try TailscaleNode(config: config, logger: logger)
            try await ts2.up()

            let ts1_addr = try await ts1.addrs()
            let ts2_addr = try await ts2.addrs()

            print("ts1 addresses are \(ts1_addr)")
            print("ts2_adddresses are \(ts2_addr)")

            let msgReceived = expectation(description: "ex")
            let lisetnerUp = expectation(description: "lisetnerUp")

            var listenerAddr: String?
            var writerAddr: String?

            switch netType {
            case .v4:
                listenerAddr = ts1_addr.ip4
                writerAddr = ts2_addr.ip4
            case .v6:
                // barnstar: Validity of listener IPs is loadbearing.  accept fails
                // in the C code if you listen on an invalid addr.
                listenerAddr = if let a = ts1_addr.ip6 { "[\(a)]"} else { nil }
                writerAddr = if let a = ts2_addr.ip6 { "[\(a)]"} else { nil }
            case .none:
                XCTFail("Invalid IP Type")
            }

            guard let ts1Handle = await ts1.tailscale,
                  let ts2Handle = await ts2.tailscale,
                  let listenerAddr,
                  let writerAddr else {
                XCTFail()
                return
            }

            // Run a listener in a separate task, wait for the inbound
            // connection and read the data
            Task {
                let listener = try Listener(tailscale: ts1Handle,
                                              proto: .tcp,
                                              address: ":8081",
                                              logger: logger)
                lisetnerUp.fulfill()
                let inbound = try await listener.accept()
                await listener.close()

                // We can trust the baackend her
                let inboundIP = await inbound.remoteAddress
                XCTAssertEqual(inboundIP, writerAddr)

                let got = try await inbound.receiveMessage(timeout: 2)
                print("got \(got)")
                XCTAssert(got == want)

                msgReceived.fulfill()
            }

            //Make sure somebody is listening
            await fulfillment(of: [lisetnerUp], timeout: 5.0)

            let outgoing = try await OutgoingConnection(tailscale: ts2Handle,
                                            to: "\(listenerAddr):8081",
                                            proto: .tcp,
                                            logger: logger)
            try await outgoing.connect()

            print("sending \(want)")
            try await outgoing.send(want)

            await fulfillment(of: [msgReceived], timeout: 5.0)

            print("closing  conn")
            await outgoing.close()

            try await ts1.down()
            try await ts2.down()
        } catch {
            XCTFail("Init Failed: \(error)")
        }
    }

    func mockConfig() -> Configuration {
        let temp = getDocumentDirectoryPath().absoluteString + "tailscale"
        return Configuration(
            hostName: "testHost",
            path: temp,
            authKey: "key",
            controlURL: controlURL,
            ephemeral: false)
    }
}


func getDocumentDirectoryPath() -> URL {
    let arrayPaths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let docDirectoryPath = arrayPaths[0]
    return docDirectoryPath
}
