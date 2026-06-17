# Security

## Secrets handling

API credentials live in `App/Support/Secrets.plist`, which is **git-ignored** and
must never be committed. Use `App/Support/Secrets.plist.example` as a template:

```sh
cp App/Support/Secrets.plist.example App/Support/Secrets.plist
# then fill in your own keys
```

Supported keys: `TFL_APP_ID`, `TFL_APP_KEY`, `OPENWEATHER_API_KEY`,
`REALTIMETRAINS_BASE_URL`, `REALTIMETRAINS_API_KEY`, `REALTIMETRAINS_USERNAME`,
`REALTIMETRAINS_PASSWORD`, `HERE_API_KEY`, `GOOGLE_MAPS_API_KEY`.

## ⚠️ Previously committed credentials — rotate immediately

`Secrets.plist` was tracked in earlier commits and exposed live credentials in
git history. Removing the file from tracking (this change) does **not** remove it
from history. You must:

1. **Rotate** every credential that was ever committed:
   - TfL app key
   - OpenWeather API key
   - RealtimeTrains username/password
   - HERE API key (it was also present in `Secrets.plist.example`)
2. **Scrub history** so the old values are unreachable, e.g. with
   [`git filter-repo`](https://github.com/newren/git-filter-repo) or the BFG:
   ```sh
   git filter-repo --path App/Support/Secrets.plist --invert-paths
   ```
   (Coordinate with collaborators — this rewrites history and requires a
   force-push by a maintainer.)
3. Confirm the keys are revoked at each provider's dashboard.
