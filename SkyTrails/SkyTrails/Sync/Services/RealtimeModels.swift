//
//  RealtimeModels.swift
//  SkyTrails
//
//  Decodable structs for Supabase Realtime payloads
//

import Foundation

// MARK: - Realtime Event Types

enum RealtimeEventType: String, Decodable {
    case insert = "INSERT"
    case update = "UPDATE"
    case delete = "DELETE"
    
    var syncStatus: SyncStatus {
        switch self {
        case .insert, .update:
            return .synced
        case .delete:
            return .pendingDelete
        }
    }
}

// MARK: - Realtime Payload

struct RealtimePayload: Decodable {
    let type: RealtimeEventType
    let table: String
    let schema: String
    let record: [String: JSONValue]?
    let oldRecord: [String: JSONValue]?
    
    enum CodingKeys: String, CodingKey {
        case type
        case table
        case schema
        case record
        case oldRecord = "old_record"
    }
}

// MARK: - JSON Value (Flexible Decoding)

enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null
    
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
    
    var doubleValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }
    
    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }
    
    var uuidValue: UUID? {
        guard let string = stringValue else { return nil }
        return UUID(uuidString: string)
    }
    
    var dateValue: Date? {
        guard let string = stringValue else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }
}

// MARK: - Record Extraction Helpers

extension [String: JSONValue] {
    func string(for key: String) -> String? {
        self[key]?.stringValue
    }
    
    func double(for key: String) -> Double? {
        self[key]?.doubleValue
    }
    
    func bool(for key: String) -> Bool? {
        self[key]?.boolValue
    }
    
    func uuid(for key: String) -> UUID? {
        self[key]?.uuidValue
    }
    
    func date(for key: String) -> Date? {
        self[key]?.dateValue
    }
    
    func int(for key: String) -> Int? {
        self[key]?.doubleValue.flatMap(Int.init)
    }
}

// MARK: - Supabase Realtime Message

struct RealtimeMessage: Decodable {
    let topic: String
    let event: String
    let payload: RealtimePayload
    let ref: String?
}

// MARK: - Channel Subscription

struct RealtimeChannel: Encodable {
    let topic: String
    let event: String = "phx_join"
    let payload: RealtimeChannelPayload
    let ref: String = UUID().uuidString
}

struct RealtimeChannelPayload: Encodable {
    let config: RealtimeChannelConfig
}

struct RealtimeChannelConfig: Encodable {
    let broadcast: RealtimeBroadcastConfig
    let presence: RealtimePresenceConfig
    let postgresChanges: [RealtimePostgresChange]
    
    init(postgresChanges: [RealtimePostgresChange]) {
        self.broadcast = RealtimeBroadcastConfig(ack: false, selfBroadcast: false)
        self.presence = RealtimePresenceConfig(key: "")
        self.postgresChanges = postgresChanges
    }
}

struct RealtimeBroadcastConfig: Encodable {
    let ack: Bool
    let selfBroadcast: Bool
    
    enum CodingKeys: String, CodingKey {
        case ack
        case selfBroadcast = "self"
    }
}

struct RealtimePresenceConfig: Encodable {
    let key: String
}

struct RealtimePostgresChange: Encodable {
    let event: String  // "*", "INSERT", "UPDATE", "DELETE"
    let schema: String = "public"
    let table: String
    
    init(event: String = "*", table: String) {
        self.event = event
        self.table = table
    }
}

// MARK: - Heartbeat

struct RealtimeHeartbeat: Encodable {
    let topic: String = "phoenix"
    let event: String = "heartbeat"
    let payload: [String: String] = [:]
    let ref: String
    
    init(ref: String = UUID().uuidString) {
        self.ref = ref
    }
}
