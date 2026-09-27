# Hums Search & Discovery API Specification

---

## 1. Catalog Search

### `GET /api/v1/search`

Executes multi-entity catalog search with ranking, typo tolerance, and server-side privacy enforcement.

#### Request Parameters
| Parameter | Type | Required | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `q` | `string` | No | `""` | Search query string (case-insensitive, trimmed, UTF-8 supported) |
| `type` | `string` | No | `"all"` | Filter category: `all`, `tracks`, `artists`, `albums`, `playlists`, `podcasts`, `episodes` |
| `limit` | `integer` | No | `20` | Maximum items returned per entity category (`1` - `50`) |
| `skip` | `integer` | No | `0` | Pagination offset for category-specific browsing |

#### Headers
| Header | Description |
| :--- | :--- |
| `Authorization` | *(Optional)* Bearer token `Bearer <jwt_token>` for authenticated playlist ownership visibility |

#### Rate Limits
- **Quota:** 60 requests/minute per client IP or authenticated session.
- **Status Code:** `429 Too Many Requests` when quota exceeded.

#### Response `200 OK`
```json
{
  "success": true,
  "data": {
    "query": "arijit",
    "type": "all",
    "total_tracks": 2,
    "total_artists": 1,
    "total_albums": 1,
    "total_playlists": 0,
    "total_podcasts": 0,
    "total_episodes": 0,
    "tracks": [
      {
        "id": "18f98a28-66a8-4ce6-a78b-d72b2fe6f6c9",
        "owner_id": "0d6e64ec-9e90-4886-8ad3-6df8ba04e9c7",
        "title": "Kesariya",
        "description": null,
        "artist_name": "Arijit Singh",
        "album_name": "Brahmastra",
        "genre": "Romantic",
        "duration_seconds": 268,
        "waveform_key": null,
        "status": "READY",
        "created_at": "2026-09-24T20:56:00Z",
        "updated_at": "2026-09-24T20:56:00Z"
      }
    ],
    "artists": [
      {
        "id": "artist_a5cb6062-8822-5ea8-b391-496e5bdafe96",
        "name": "Arijit Singh",
        "username": null,
        "avatar_url": null,
        "bio": null,
        "track_count": 14
      }
    ],
    "albums": [
      {
        "id": "album_bc841bb2-f831-50e4-b77a-ea4c34a2e88a",
        "title": "Brahmastra",
        "artist_name": "Arijit Singh",
        "track_count": 6,
        "cover_image_key": null,
        "cover_image_url": null
      }
    ],
    "playlists": [],
    "podcasts": [],
    "episodes": []
  }
}
```

---

## 2. Autocomplete Suggestions

### `GET /api/v1/search/suggestions`

Returns fast, ranked completion suggestions across titles, artists, albums, and playlists.

#### Request Parameters
| Parameter | Type | Required | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `q` | `string` | No | `""` | Search prefix or partial query |
| `limit` | `integer` | No | `8` | Maximum suggestions returned (`1` - `20`) |

#### Rate Limits
- **Quota:** 120 requests/minute per client IP or authenticated session.

#### Response `200 OK`
```json
{
  "success": true,
  "data": {
    "query": "ari",
    "suggestions": [
      "Arijit Singh",
      "Aashiqui 2",
      "Apna Bana Le"
    ]
  }
}
```
