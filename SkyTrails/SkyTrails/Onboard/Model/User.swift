//
//  User.swift
//  SkyTrails
//
//  Created by MIT WPU on 24/12/25.
//

import Foundation

struct User: Codable {

    var id: UUID
    var name: String
    var gender: String
    var email: String
    var profilePhoto: String

    init(
        id: UUID = UUID(),
        name: String,
        gender: String,
        email: String,
        profilePhoto: String
    ) {
        self.id = id
        self.name = name
        self.gender = gender
        self.email = email
        self.profilePhoto = profilePhoto
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case gender
        case email
        case profilePhoto
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.gender = try container.decode(String.self, forKey: .gender)
        self.email = try container.decode(String.self, forKey: .email)
        self.profilePhoto = try container.decode(String.self, forKey: .profilePhoto)
    }
}
