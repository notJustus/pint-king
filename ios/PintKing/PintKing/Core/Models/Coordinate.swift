//
//  Coordinate.swift
//  PintKing
//
//  A plain latitude/longitude pair. Kept separate from CoreLocation's
//  CLLocationCoordinate2D so the domain layer stays free of framework types
//  and remains trivially Codable/Equatable.
//

import Foundation

struct Coordinate: Codable, Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}
