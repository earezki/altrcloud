### resources
* Deep link : https://medium.com/flutter-community/deep-links-and-flutter-applications-how-to-handle-them-properly-8c9865af9283
* Deep link redirect issue solution: https://github.com/openid/AppAuth-Android/issues/977
* For Github try device flow to avoid having the secret https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow

### What is:
Initially this project started with a different idea, but at the core, an alternate cloud storage solution, then I settled on a Github storage but I kept some elements of previous design around.
This is a proof of concept to see if Github could be used to store personal securely data such as photo and videos.
I created this application for myself first, and I'm maintaining/adding features for it when they make sens, I'm using the application daily.
The data is stored in private Github repositories, and for added security, the data in encrypted/decrypted on device.
The repositories are created by the application when old ones are full, but the storage is managed by Github and not the application.
If you delete the repository/files manually from your Github account, the data is lost.

### Github connecting steps:
1. create a github account
2. create an oauth application and assign your own clientid / secret because of the api rate limit.
3. create an organization with name starting with **altrcloud**
4. give permission to the organization via: https://github.com/settings/connections/applications/:clientId
5. connect user via the application.

TODO: 
1. check & renew token after expiration
2. Offload the ui-thread.
3. Download
4. favorites
5. video compression option
6. flash back story (inspired by google photos)
7. search by objects (cars, cats, people, ...)

### **Features**:
* User authentication and connection to Github.
* Upload photos & videos.
* Notification and error handling.
* Simple Search: by type (Photo, Video, Screeshot) or by full name.
* Group content by date
* Usage Analytics.
* End-to-End Encryption: every thing is encrypted/decrypted on the device itself.
* Caching for faster retrieval.
* Resume upload of large files (videos)
* works only on private repositories

### **What's not**:
* Not a collaboration app, it's not optimized to be used by multiple devices at the same time.
* Not a Github application, you need to create an application and set your keys to avoid api rate limits (https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api?apiVersion=2022-11-28)

### **Challenges**:
* Impossible to do modifications in parallel, Github will refuse those writes as they would result in a conflict in the git repository.
* A possible solution is to upload in parallel to different repositories.
* We should find a balance for the parallel download because this could result in out of memory errors.

### **How to use**:
* Got to the *organizations* page in your Github account settings. (https://github.com/settings/organizations)
* Click on the *New organization* button.
* Create an organization that starts with *altrcloud*. (exp: altrcloud-earezki)
* Got to the *Developer settings* of the new organization, then select OAuth Apps. (https://github.com/organizations/${org_name}/settings/applications)
* Click on *New OAuth app*, fill in the *Authorization callback URL* with **altrcloud://callback**, and check the **Enable Device Flow**, then set *Application name* and *Homepage URL* to whatever you like. Finally click on *Register application*.
* Copy the *Client ID*
* Click on *generate a new client secret*, the copy the value because it will be visible only once.
* Go to the *Settings* page in the *GitPhoto* application.
* Click on *Client credentials*, then fill in the *Client ID* and the *Client secret*. (They will be stored locally on the phone)
* Click on the *Github* button in the same *Settings* page.
* Give the application the requested permissions to manage the organization and it's private repositories. (the generated token will be stored locally in the phone)
* Go back to the *Gallery* page, then click on the *upload* button. (Floating button in the button to the right)

### **FAQ**:
* If the video's colors are bad or not playing correctly, then please use the *open with* option from the menu in the video screen.
* If you face issue while uploading a video, then try the *resolve conflict* option. (**WARNING** this will try to delete duplicated contents from the remote storage, so use it carefully)
* If you want to synchronize two devices, make sure that *Sync* is enabled or else trigger it manually.