# Notice

I am trying to raise money to implement a caching system to RSS Box. To learn more, please go to this issue: https://github.com/stefansundin/rssbox/issues/43

# RSS Box

This app uses the API of other websites and gives you an RSS feed in return. Quick and simple.

To open `vlc://` links, see [vlc-protocol](https://github.com/stefansundin/vlc-protocol).

You can use this app freely at [rssbox.herokuapp.com](https://rssbox.herokuapp.com/). An experimental Elastic Beanstalk version [is available](https://rssbox.us-west-2.elasticbeanstalk.com/).

## Roll your own

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/stefansundin/rssbox)

To deploy to Elastic Beanstalk, see [.ebextensions/README.md](.ebextensions/README.md).

To deploy to Kubernetes, see [kubernetes/README.md](kubernetes/README.md).

A Docker image is available on [Docker Hub](https://hub.docker.com/r/stefansundin/rssbox).

#### Heroku

If you need to re-provision redis, or you didn't use the deploy button above to provision the app initially, then you need to make sure to set the maxmemory policy:

```
heroku redis:maxmemory --policy=allkeys-lru
```

### Configuration

You need to get API keys for the respective services and populate the environment variables, e.g. by using an [.env](.env.example) file.

A couple of services do not have official APIs, or do not require API keys, so they will work without any keys.

These services do not require API keys: Instagram, Periscope, Mixcloud, Speedrun, Ustream, Dailymotion.

#### Twitter

Go to [Twitter Application Management](https://apps.twitter.com/) and create a new app.

Once you have the consumer key and consumer secret, run the following to get the bearer token.

```
curl -X POST -d grant_type=client_credentials -u CONSUMER_KEY:CONSUMER_SECRET https://api.twitter.com/oauth2/token
```

Copy the `access_token` and put it in the config.

#### YouTube

Go to the [Google Developer Console](https://console.developers.google.com/), create a project and a server key. Copy the server key. Enable "YouTube Data API v3" in the project.

#### Vimeo

Go to the [Vimeo developer website](https://developer.vimeo.com/apps) and create an app. Then create a personal access token.

#### Facebook

Facebook was supported in the past, but I have been unable to obtain API access since they locked it down in 2018. Maybe we can rebuild it some day, but using scraping techniques or something. [Discuss here.](https://github.com/stefansundin/rssbox/issues/5)

#### SoundCloud

Go to the [SoundCloud developer website](https://soundcloud.com/you/apps) and create an app. Copy your client id and secret.

#### Twitch

Go to your [Twitch settings](https://www.twitch.tv/settings/connections) and create an app. Copy your client id.

To download Twitch videos, you also need to configure a separate client id.

#### Imgur

Go to the [Imgur settings](https://imgur.com/account/settings/apps) and create an app. Copy your client id.
