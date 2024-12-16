### What is:
Initially this project started with a different idea, but at the core, an alternate cloud storage solution, then I settled on a Github storage but I kept some elements of previous design around.
This is a proof of concept to see if Github could be used to store personal securely data such as photo and videos.
I created this application for myself first, and I'm maintaining/adding features for it when they make sens, I'm using the application daily.
The data is stored in private Github repositories, and for added security, the data in encrypted/decrypted on device.
The repositories are created by the application when old ones are full, but the storage is managed by Github and not the application.
If you delete the repository/files manually from your Github account, the data is lost.

### **TODO**: 
1. check & renew token after expiration
2. Offload the ui-thread.
3. Download
4. favorites
5. video compression option
6. flash back story (inspired by google photos)
7. search by objects (cars, cats, people, ...)

### **Features**:
* User authentication and connection to Github.
* Basic cross-device synchronizations.
* Upload photos & videos.
* Notification and error handling.
* Basic Search: by type (Photo, Video, Screeshot) or by full name.
* Group content by date
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
1. Go to the **_organizations_** page in your Github account settings. (https://github.com/settings/organizations)
2. Click on the _**New organization**_ button.
3. Create an organization that starts with **_altrcloud_**. (exp: altrcloud-earezki)
4. Got to the **_Developer settings_** of the new organization, then select **_OAuth Apps_**. (https://github.com/organizations/${org_name}/settings/applications)
5. Click on **_New OAuth app_**, fill in the **_Authorization callback URL_** with **altrcloud://callback**, and check the **Enable Device Flow**, then set **_Application name_** and **_Homepage URL_** to whatever you like. Finally click on ***Register application***.
6. Copy the *Client ID*
7. Click on *generate a new client secret*, then copy the value because it will be visible only once.
8. Go to the *Settings* page in the *GitPhoto* application.
9. Click on *Client credentials*, then fill in the *Client ID* and the *Client secret*. (They will be stored locally on the phone)
10. Click on the *Github* button in the same *Settings* page.
11. Give the application the requested permissions to manage the organization and it's private repositories. (the generated token will be stored locally in the phone)
12. Go back to the *Gallery* page, then click on the **_upload_** button. (Floating button in the bottom to the right)

### **How to get**:
#### **Build from source**:
```shell
git clone
cd project directory
flutter build apk --release --obfuscate --split-debug-info=.\build\app\outputs\flutter-apk\debug-info
```
#### **Get it on Github**:
[<img alt="GitPhoto" width="250px" src="./get_it_on_github.png" />](https://github.com/earezki/altrcloud/releases/latest/)

### **FAQ**:
* If the video's colors are bad or not playing correctly, then please use the *open with* option from the menu in the video screen.
* If you face issue while uploading a video, then try the *resolve conflict* option. ( **WARNING** this will try to delete duplicated contents from the remote storage, so use it carefully )
* If you want to synchronize two devices, make sure that *Sync* is enabled or else trigger it manually.

### **License**

```
Copyright (C) 2024 GitPhoto

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

Usage conditions:
- Copied/Modified version of this software can not be used for 'non-free' and profit purposes.
- You can not publish copied/modified version of this app on closed source app repository
  like PlayStore/AppStore.
---

#### Disclaimer of Warranty
THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT
HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT
WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND
PERFORMANCE OF THE PROGRAM IS WITH YOU. SHOULD THE PROGRAM PROVE
DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR, OR
CORRECTION.

You should have received a copy of the GNU General Public License
along with this program. If not, you can find the full GPL v3.0 license text here: https://www.gnu.org/licenses/gpl-3.0.html.
```
