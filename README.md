# BookNook iOS

iOS version of BookNook, a social app for book clubs. Built with SwiftUI and backed by the Express + SQLite server in `server/`.

## Requirements

- Xcode 26 or later (iOS 17+ deployment target)
- Node.js 22 or later

## Run the server

```bash
cd server
cp .env.example .env   # then fill in JWT_SECRET and GOOGLE_BOOKS_API_KEY
npm install
npm run seed           # optional: demo users, clubs and chats in Spanish
npm run dev
```

The server listens on port 4000.

`npm run seed` creates 10 demo readers (`valeria@booknook.mx`, `mateo@booknook.mx`, … all with the password `lectura123`) and 7 clubs with chats and polls. Two clubs are private: *Lectores Nocturnos* (code `LUNA27`) and *Misterio en la Biblioteca* (code `CLAVE8`). Running it again replaces the demo data and leaves other accounts untouched. Book search uses the Google Books API; create a key in Google Cloud Console with the Books API enabled.

## Run the app

1. Open `BookNook.xcodeproj` in Xcode.
2. Pick a simulator and press Run. The app uses `http://localhost:4000` by default.

### On an iPhone

1. In Xcode › Settings › Accounts, sign in with your Apple ID.
2. In the BookNook target › Signing & Capabilities, choose your team. Change the bundle identifier if Xcode asks.
3. Turn on Developer Mode on the iPhone (Settings › Privacy & Security), connect it and press Run.
4. Keep the iPhone and the Mac on the same Wi‑Fi network. On the login screen tap the server icon and enter `http://<your-mac-ip>:4000`.

## Project structure

```
BookNook/            SwiftUI app
  App/               entry point and root navigation
  Core/              networking, session, keychain, server settings
  Models/            API models
  Features/          screens grouped by feature
  Theme/             colors, fonts and shared styles
Config/Info.plist    network permissions
server/              Express + SQLite API
```
