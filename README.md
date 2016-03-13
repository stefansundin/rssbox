# RSS Box [![Code Climate](https://codeclimate.com/github/stefansundin/rssbox/badges/gpa.svg)](https://codeclimate.com/github/stefansundin/rssbox)

You can use this app freely at [rssbox.herokuapp.com](https://rssbox.herokuapp.com/).

## Roll your own

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

### Configuration

You need to get API keys for the respective services and populate the environment variables, e.g. by using an [.env](.env.example) file.

#### Google

Go to the [Google Developer Console](https://console.developers.google.com/), create a project and a server key. Copy the server key.

Enable the following APIs in the project:
- YouTube Data API v3
- Google+ API

#### Facebook

Go to the [Facebook developer website](https://developers.facebook.com/) and create an app. Copy your app id and secret.

#### Instagram

Go to the [Instagram developer website](http://instagram.com/developer/) and create a client. Copy your client id and secret.

#### SoundCloud

Go to the [SoundCloud developer website](http://soundcloud.com/you/apps) and create an app. Copy your client id and secret.

#### Imgur

Go to the [Imgur settings](https://imgur.com/account/settings/apps) and create an app. Copy your client id.
