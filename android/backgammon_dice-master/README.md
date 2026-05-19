# Backgammon Dice
Simple two dice app.

Some concepts that is used in this app:

**Animation**
Shake animation of the in the introduction dialogue.
Rotation animaton of the dices while rolling the dices.

**MediaPlayer**
MediaPlayer is used to play dice sound file.

**SensorManager**
SensorManager is used to detect the shake movement.

**Ktlint** and **detekt** used to follow best coding practices. 

**SharedPreferences** is implemented as a seperate file and instantiated at Application file to provide easy app-wide access.

**Tags** for the activities are created as following example:
`private val tag: String = MainActivity::class.java.getName()`

**Versioning**
Two functions are created namely `computeVersionName` and `computeVersionCode`

`computeVersionName` simply combines `versionMajor` and `versionMinor` properties as a string.

`computeVersionCode` in order to ensure that we have unique version code; versionMajor is multiplied by 100.000 and versionMinor is minor is multiplied by 10.000 and added on top of the previous result. In every build in CI system there will be unique build number as well and this build number will be read from the environment variables and added on top of the total. Build number can be read from the GitHub actions as `System.env.GITHUB_RUN_NUMBER`. This number is not manually created and defaultly available on the GitHub Actions build.

GitHub Actions is used to run unit tests and upload APK to the Google Play. If needed we can also upload generated aab file to the repo as well.

 `unit_test.yml` workflow runs the unit tests and Espresso UI tests in the app.
 
 One interesting note about Espresso ui tests is that, it waits patiently to animations in the app to finish. But if you have repeating animation which goes on forever this would make your espresso test to eventually crash. It is suggested to disabled animations in your emulator or device but this does not work for all the animations. In this code as a work around, it is checked if the test is running and animation running dialog view is not shown in that case.
 
 `upload_to_google_play.yml` workflow have bit more heavier work included. There are some files and password strings which are required to sign and upload the app to the Google Play. Those files and strings are registered in GitHub as secrets and various actions in the workflow use those secrets when needed.
 
 Both workflows will be triggered when there is a push or pull request on the master branch.

<img src=bg1.png width="250"> <img src=bg2.png width="250"> <img src=bg3.png width="250">
