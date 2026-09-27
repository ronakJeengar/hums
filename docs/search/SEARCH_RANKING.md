# Search Ranking & Text Normalization Strategy

---

## 1. Relevance Scoring Model

SearchResults are ordered by a deterministic multi-signal relevance scoring expression computed directly in SQL:

```
Relevance Score =
    Exact Match (100 pts)
  + Prefix Match (50 pts)
  + Substring Match (25 pts)
  + Secondary Field Match (15 pts)
  + Trigram Word Similarity (scaled up to 20 pts, threshold > 0.35)
```

### Detailed Field Weights

| Entity | Field | Match Type | Weight |
| :--- | :--- | :--- | :--- |
| **Track** | `title` | Exact Match (`lower(title) == query`) | +100.0 |
| | `artist_name` | Exact Match | +80.0 |
| | `title` | Prefix Match (`title ILIKE 'query%'`) | +50.0 |
| | `artist_name` | Prefix Match | +40.0 |
| | `title` | Substring Match (`title ILIKE '%query%'`) | +25.0 |
| | `artist_name` | Substring Match | +20.0 |
| | `album_name` | Substring Match | +15.0 |
| | `genre` | Substring Match | +10.0 |
| | `title` | `word_similarity(query, title)` | * 20.0 |
| | `artist_name` | `word_similarity(query, artist_name)` | * 15.0 |
| **Artist** | `full_name` / `username` | Exact Match | +100.0 / +90.0 |
| | `full_name` / `username` | Prefix Match | +50.0 / +45.0 |
| | `full_name` / `username` | Substring Match | +25.0 / +20.0 |
| | `full_name` / `username` | `word_similarity` | * 20.0 / * 15.0 |
| **Album** | `album_name` | Exact Match | +100.0 |
| | `album_name` | Prefix Match | +50.0 |
| | `album_name` | Substring Match | +25.0 |
| | `artist_name` | Substring Match | +15.0 |
| | `album_name` | `word_similarity` | * 20.0 |
| **Playlist** | `name` | Exact Match | +100.0 |
| | `name` | Prefix Match | +50.0 |
| | `name` | Substring Match | +25.0 |
| | `description` | Substring Match | +10.0 |
| | `name` | `word_similarity` | * 20.0 |

---

## 2. Text Normalization

Before query execution:
1. **Trimming:** Leading and trailing whitespace is stripped.
2. **LIKE Escaping:** Wildcard characters (`%`, `_`, `\`) are escaped using `_escape_like_pattern` to prevent wildcard DOS or unintended filtering.
3. **Case Normalization:** Case-insensitive search via PostgreSQL `ILIKE` and `lower()` comparison.
4. **Multilingual & Indian Languages:** Full UTF-8 support handles Hindi, Devanagari script (e.g. "केसरिया", "तुम ही हो"), Hinglish, and regional character sets without character degradation.
