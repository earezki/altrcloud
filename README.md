### resources
Deep link : https://medium.com/flutter-community/deep-links-and-flutter-applications-how-to-handle-them-properly-8c9865af9283
Deep link redirect issue solution: https://github.com/openid/AppAuth-Android/issues/977
For Github try device flow to avoid having the secret https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow

### Github connecting steps:
1. create a github account
2. create an oauth application and assign your own clientid / secret because of the api rate limit.
3. create an organization with name starting with **altrcloud**
4. give permission to the organization via: https://github.com/settings/connections/applications/:clientId
5. connect user via the application.

TODO: 
1. check & renew token after expiration
2. Download
3. favorites
4. video compression option
5. flash back story (inspired by google photos)
6. search by objects (cars, cats, people, ...)

### High-Level Plan

**Features**:
    - User authentication and connection to Github.
    - Upload photos & videos.
    - Notification and error handling.
    - Simple Search: by type (Photo, Video, Screeshot) or by full name.
    - Group content by date
    - Usage Analytics.
    - End-to-End Encryption: every thing is encrypted/decrypted on the device itself.
    - Caching for faster retrieval.
    - Resume upload of large files (videos)
    - works only on private repositories

**What's not**:
    - Not a collaboration app, it's not optimized to be used by multiple devices at the same time.
    - Not a Github application, you need to create an application and set your keys to avoid api rate limits (https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api?apiVersion=2022-11-28)
