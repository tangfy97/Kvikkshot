# Kvikkshot on tang-spark.no

The product and support pages live in the [tang-spark.no](https://github.com/tangfy97/tang-spark.no) repo, which Netlify deploys from `main`. Their source is here, so the copy, the version and the download stay in step with the app.

| Page | URL |
|---|---|
| Product (EN, 简体, 繁體) | `/kvikkshot.html`, `/kvikkshot-zh-cn.html`, `/kvikkshot-zh-tw.html` |
| Support, privacy, terms | `/kvikkshot-support.html` (+ `-zh-cn`, `-zh-tw`); privacy is `#privacy` |
| Latest disk image | `/kvikkshot/download`, a redirect to `/downloads/Kvikkshot-<version>.dmg` |

The app's Help menu links to these pages in the language it runs in ([Links.swift](../Kvikkshot/Links.swift)). In the downloaded version, Help › Check for a New Version opens the product page with `?installed=<version>`, and the page says whether a newer version exists.

## Files here

- `website/generate.py`: the copy in all three languages and the page templates. It reads the version from `project.yml` and the size and SHA-256 from the notarized disk image.
- `website/static/kvikkshot.css`: styles on top of the site's `styles.css` (the `launch-*` layout shared with Echoknot).
- `website/static/kvikkshot/`: the icon, app screenshots and the social preview image.
- `website/tang-spark-homepage.patch`: the one-time homepage change (Kvikkshot in the Products menu and the Apps grid, two products side by side).

## Publishing a release

```bash
scripts/release.sh                                  # notarized build/release/Kvikkshot-<version>.dmg
scripts/publish-website.sh ~/Documents/tang-spark.no
git -C ~/Documents/tang-spark.no add -A && git -C ~/Documents/tang-spark.no commit -m "Kvikkshot <version>"
git -C ~/Documents/tang-spark.no push
```

`publish-website.sh` refuses a disk image that isn't notarized, regenerates the pages, copies them with the images and the disk image, and points `/kvikkshot/download` at the new version in `netlify.toml`. It never commits or pushes. The first time, also apply the homepage patch:

```bash
git -C ~/Documents/tang-spark.no apply ~/Documents/Kvikkshot/website/tang-spark-homepage.patch
```

Once the app is live on the App Store, set `APP_STORE_URL` in `website/generate.py` to show the Mac App Store button, and publish again.
