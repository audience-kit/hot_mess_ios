//
//  Fixtures.swift
//  HotMessTests
//

import Foundation

/// Sample payloads, held inline so the tests never depend on bundle resources
/// or on a server being reachable.
///
/// The old suite authenticated against Facebook with a token committed to the
/// repository and then hit the live API, so it could neither run offline nor
/// tell a regression from an outage.
enum Fixtures {
    static let venue = """
    {
      "id": "8B4F1B60-9A5D-4D0E-9B3F-2C6B3E5D8A11",
      "name": "The Stud",
      "description": "Since 1966.",
      "distance": 412.5,
      "photo_url": "https://cdn.hotmess.social/venues/stud.jpg",
      "hero_url": "https://cdn.hotmess.social/venues/stud-hero.jpg",
      "point": { "x": -122.4099, "y": 37.7726 },
      "profile": {
        "address": "399 9th St",
        "phone": "+14158633373",
        "facebook": { "facebook_id": "112233445566", "is_liked": true }
      }
    }
    """

    /// Only the fields the API always sends.
    static let minimalVenue = """
    {
      "id": "1E0B9F3C-6F42-4B8E-9C7A-0D5E4A2B7C90",
      "name": "Pop-up"
    }
    """

    static let event = """
    {
      "id": "3C6E2A18-55B7-4C3D-8E21-9F0A7B4D6E22",
      "name": "Some Thing",
      "start_at": "2017-04-26T21:00:00.000-0700",
      "end_at": "2017-04-27T02:00:00.000-0700",
      "facebook_id": 998877665544,
      "is_featured": true,
      "rsvp": "decliend",
      "banner_url": "https://cdn.hotmess.social/events/some-thing.jpg",
      "venue": { "name": "Pop-up", "venue": \(minimalVenue) }
    }
    """

    /// No venue, no end date, no RSVP, and an ISO 8601 start.
    static let sparseEvent = """
    {
      "id": "7A1D4E90-2B33-4F8C-A5D6-1E9C0B2A3F44",
      "name": "Afters",
      "start_at": "2017-04-27T06:30:00Z",
      "facebook_id": "11"
    }
    """

    static let eventListing = """
    {
      "sections": {
        "later": {
          "title": "Later This Week",
          "events": [\(sparseEvent)]
        },
        "tonight": {
          "title": "Tonight",
          "events": [\(event)]
        },
        "empty": {
          "title": "Nothing Here",
          "events": []
        }
      }
    }
    """

    static let personDetail = """
    {
      "id": "4D9A0C21-8E76-4A5B-B3C2-6F1D8E0A9B33",
      "name": "Rick Mark",
      "role": "Resident",
      "photo_url": "https://cdn.hotmess.social/people/rick.jpg",
      "profile": {
        "facebook": { "facebook_id": 12345, "is_liked": false },
        "social_links": {
          "nodes": [
            {
              "id": "9F2B7C40-1A5E-4D83-9E6C-2B0A7D4F8C55",
              "handle": "hotmess",
              "provider": "instagram",
              "url": "https://instagram.com/hotmess"
            }
          ]
        }
      },
      "music": {
        "tracks": {
          "nodes": [
            {
              "id": "2A8E5D13-7C90-4B6F-8D2A-5E1C9B0F3A66",
              "title": "Set One",
              "provider": "soundcloud",
              "provider_url": "https://soundcloud.com/hotmess/set-one",
              "waveform_url": "https://cdn.hotmess.social/wave.png",
              "artwork_url": "https://cdn.hotmess.social/art.png"
            }
          ]
        }
      },
      "members": [
        {
          "id": "6E1F3A92-0B4C-4D7E-8F15-3A9C2D6B1E77",
          "name": "Ada Lovelace",
          "photo_url": "https://cdn.hotmess.social/people/ada.jpg"
        }
      ],
      "groups": [
        { "id": "7F2A4B03-1C5D-4E8F-9A26-4B0D3E7C2F88", "name": "The Haus of Mess" }
      ],
      "events": { "upcoming": { "nodes": [\(sparseEvent)] } }
    }
    """

    /// A venue as its detail query returns it, with events, friends and links.
    static let venueDetail = """
    {
      "id": "8B4F1B60-9A5D-4D0E-9B3F-2C6B3E5D8A11",
      "name": "The Stud",
      "chat_open": true,
      "events": { "upcoming": { "nodes": [\(sparseEvent)] } },
      "friends": { "list": { "nodes": [] } },
      "profile": {
        "address": "399 9th St",
        "facebook": { "facebook_id": null, "is_liked": false },
        "social_links": {
          "nodes": [
            {
              "id": "0C3B5D14-2E6F-4A90-8B37-5C1E4F8D3A99",
              "handle": "thestudsf",
              "provider": "instagram",
              "url": "https://instagram.com/thestudsf"
            }
          ]
        }
      }
    }
    """

    /// The device is somewhere we know about, so `nearby_venues` is present.
    static let nowNearVenues = """
    {
      "venue": null,
      "nearby_venues": [\(venue)],
      "locale": {
        "id": "4E5F6071-8293-4A41-8D5E-6F7A8B9C0D1E",
        "name": "SoMa",
        "hero_url": "https://cdn.hotmess.social/now.jpg",
        "events": { "upcoming": { "nodes": [\(sparseEvent)] } }
      }
    }
    """

    /// No `venues` key at all — the friends-first variant of the same screen.
    static let nowWithFriends = """
    {
      "locale": {
        "id": "4E5F6071-8293-4A41-8D5E-6F7A8B9C0D1E",
        "name": "SoMa",
        "friends": {
          "list": {
            "nodes": [
              { "id": "5B3C8A72-4E19-4D06-B2F5-8C7A1E0D9B22", "name": "Ada Lovelace", "facebook_id": 42 }
            ]
          }
        }
      }
    }
    """
}
