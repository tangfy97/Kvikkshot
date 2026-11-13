# Kvikkshot on tang-spark.no

The product and support pages live in the [tang-spark.no](https://github.com/tangfy97/tang-spark.no) repo, which Netlify deploys from `main`. Their source is here, so the copy, the version and the download stay in step with the app.

| Page | URL |
|---|---|
| Product (EN, 简体, 繁體) | `/kvikkshot.html`, `/kvikkshot-zh-cn.html`, `/kvikkshot-zh-tw.html` |
| Support, privacy, terms | `/kvikkshot-support.html` (+ `-zh-cn`, `-zh-tw`); privacy is `#privacy` |
| Download | `https://github.com/tangfy97/Kvikkshot/releases/latest`; the site hosts no installers, and its `netlify.toml` redirects the old `/kvikkshot/download` links there |

The app's Help menu links to these pages in the language it runs in ([Links.swift](../Kvikkshot/Links.swift)). In the downloaded version, Help › Check for a New Version opens the product page with `?installed=<version>`, and the page says whether a newer version exists.

## Files here

- `website/generate.py`: the copy in all three languages and the page templates. It reads the version from `project.yml` and the size and SHA-256 from the notarized disk image. The English product page uses the site's Plakat layout (`styles.css`, like Spolo and Rydd); the Chinese product pages and the support pages keep the earlier `launch-*` layout, which the site serves as `legacy.css`.
- `website/static/kvikkshot.css`: styles on top of the site's `legacy.css` for the `launch-*` pages.
- `website/static/kvikkshot/`: the icon, app screenshots and the social preview image. The English page uses the icon and the English screenshot from the site's `img/` (`kvikkshot-icon.png`, `kvikkshot-shot.jpg`).
- `website/tang-spark-homepage.patch`: the one-time homepage change (Kvikkshot in the Products menu and the Apps grid, two products side by side).

## Publishing a release

```bash
scripts/release.sh                                  # notarized build/release/Kvikkshot-<version>.dmg, .zip and SHA256SUMS
gh release create v<version> build/release/Kvikkshot-<version>.dmg build/release/Kvikkshot-<version>.zip build/release/SHA256SUMS \
  --repo tangfy97/Kvikkshot --title "Kvikkshot <version>" --target main
scripts/publish-website.sh ~/Documents/tang-spark.no
git -C ~/Documents/tang-spark.no add -A && git -C ~/Documents/tang-spark.no commit -m "Kvikkshot <version>"
git -C ~/Documents/tang-spark.no push
```

The download buttons link to the latest GitHub release, so publish the release before the pages. Because the pages print the disk image's size and SHA-256, `publish-website.sh` refuses a disk image that isn't notarized or isn't the one in the GitHub release. It regenerates the pages and copies them with the images, and never copies a disk image, edits `netlify.toml`, commits or pushes. The first time, also apply the homepage patch:

```bash
git -C ~/Documents/tang-spark.no apply ~/Documents/Kvikkshot/website/tang-spark-homepage.patch
```

Once the app is live on the App Store, set `APP_STORE_URL` in `website/generate.py` to show the Mac App Store button, and publish again.
