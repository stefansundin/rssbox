# RSS Box

This app uses the API of other websites and gives you an RSS feed in return. Quick and simple.

To open `vlc://` links, see [vlc-protocol](https://github.com/stefansundin/vlc-protocol).

You can use this app freely at [rssbox.herokuapp.com](https://rssbox.herokuapp.com/).

## Roll your own

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/stefansundin/rssbox)

### Elastic Beanstalk

If you are using the free tier, then use a t2.micro instance. If not, you can use a t1.micro with spot to get the lowest price.

Create environment:
```
git tag -a -m "First deploy" eb-v1
eb init rssbox --platform "Ruby 2.5 (Puma)" --keyname id_rsa
eb create --single --instance_type t2.micro
```

For spot:
```
eb create --single --instance_type t1.micro --envvars EC2_SPOT_PRICE=0.01
```

With a load balancer:
```
eb create --instance_type t2.micro --envvars ASG_HEALTH_CHECK_TYPE=ELB
```

Deploy with:
```
eb deploy --staged
```

### Configuration

You need to get API keys for the respective services and populate the environment variables, e.g. by using an [.env](.env.example) file.

A couple of services do not have official APIs, or do not require API keys, so they will work without any keys.

#### Twitter

Go to [Twitter Application Management](https://apps.twitter.com/) and create a new app.

Once you have the consumer key and consumer secret, run the following to get the bearer token.

```
curl -X POST -d grant_type=client_credentials -u CONSUMER_KEY:CONSUMER_SECRET https://api.twitter.com/oauth2/token
```

Copy the `access_token` and put it in the config.

#### Google

Go to the [Google Developer Console](https://console.developers.google.com/), create a project and a server key. Copy the server key.

Enable the following APIs in the project:
- YouTube Data API v3
- Google+ API

#### Vimeo

Go to the [Vimeo developer website](https://developer.vimeo.com/apps) and create an app. Then create a personal access token.

#### Facebook

Go to the [Facebook developer website](https://developers.facebook.com/) and create an app. Copy your app id and secret.

Facebook live hax: After a live stream has ended, trying to access the stream via playlist.m3u8 will still give you a list of .ts files, however the domain is `interncache-prn.fbcdn.net` which doesn't resolve. However, if you edit your `/etc/hosts` file and point that domain to the IP of `origincache-prn.fbcdn.net`, you can watch the video again (use `dig origincache-prn.fbcdn.net +short`). This only works for a couple of days after the live event.

#### Instagram

Go to the [Instagram developer website](https://www.instagram.com/developer/) and create a client. Copy your client id and secret.

#### SoundCloud

Go to the [SoundCloud developer website](https://soundcloud.com/you/apps) and create an app. Copy your client id and secret.

#### Twitch

Go to your [Twitch settings](https://www.twitch.tv/settings/connections) and create an app. Copy your client id.

#### Imgur

Go to the [Imgur settings](https://imgur.com/account/settings/apps) and create an app. Copy your client id.
