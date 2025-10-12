# RSS Box

This app uses the API of other websites and gives you an RSS feed in return. Quick and simple.

List of public RSS Box instances: https://github.com/stefansundin/rssbox/discussions/64

To open `vlc://` links, see [vlc-protocol](https://github.com/stefansundin/vlc-protocol).

## Roll your own

To deploy to Elastic Beanstalk, see [.ebextensions/README.md](.ebextensions/README.md).

To deploy to Kubernetes, see [kubernetes/README.md](kubernetes/README.md).

A Docker image is available on [Docker Hub](https://hub.docker.com/r/stefansundin/rssbox) and [Amazon ECR](https://gallery.ecr.aws/stefansundin/rssbox).

**Note:** Redis is an optional dependency! It is only used for the URL resolution feature.

### Configuration

You need to get API keys for the respective services and populate the environment variables, e.g. by using an [.env](.env.example) file.

A couple of services do not have official APIs, or do not require API keys, so they will work without any keys.

These services do not require API keys: Instagram, Mixcloud, Speedrun, Dailymotion.

#### YouTube

Go to the [Google Developer Console](https://console.developers.google.com/), create a project and a server key. Copy the server key. Enable "YouTube Data API v3" in the project.

#### Vimeo

Go to the [Vimeo developer website](https://developer.vimeo.com/apps) and create an app. Then create a personal access token.

#### Instagram

> [!WARNING]
> The Instagram integration is not being maintained and may not work very well at all. You may be wasting your time.

#### Facebook

Facebook was supported in the past, but I have been unable to obtain API access since they locked it down in 2018. Maybe we can rebuild it some day, but using scraping techniques or something. [Discuss here.](https://github.com/stefansundin/rssbox/issues/5)

#### SoundCloud

Go to the [SoundCloud developer website](https://soundcloud.com/you/apps). You need to open a support ticket to create an app. Copy your client id and secret.

#### Twitch

Go to your [Twitch settings](https://www.twitch.tv/settings/connections) and create an app. Copy your client id.

To download Twitch videos, you also need to configure a separate client id.

#### Imgur

Go to the [Imgur settings](https://imgur.com/account/settings/apps) and create an app. Copy your client id.
