# found.community — Website

Static landing page for FOUND.community. Deployed to Netlify on every push to `main`.

## Local preview

Open `index.html` directly in a browser, or run:

```bash
npx serve .
```

## Deploy

Push to `main`. Netlify auto-deploys via the connected GitHub repo. Build config lives in `netlify.toml`.

## Repo layout

```
.
├── index.html       ← landing page
├── netlify.toml     ← build, headers, redirects
├── README.md
└── .gitignore
```

## Related repos

- App (React Native): https://github.com/Ryderschilling/FOUND.community
