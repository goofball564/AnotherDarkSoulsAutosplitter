# AnotherDarkSoulsAutosplitter
A Cursed Autosplitter for Dark Souls

### Current Limitations

* This script does not currently fully support versions of Dark Souls Remastered
other than current patch

* It hasn't been tested yet on a legally acquired copy of Prepare to Die Edition.

* Not every single event flag and bonfire has been tested as being correct. But they're probably mostly if not completely fine :)

* This script hasn't yet fully accomodated NG+ and Beyond.

### How to Download </br>
In the top right corner, there is a green button that says "Code". </br>
Click it, then click "Download Zip" in the dropdown menu.

### How to Install </br>
In Livesplit: Right Click -> Click "Edit Layout" -> Click (+) Button -> Hover Over "Control" -> Click "Scriptable Autosplitter" </br>
Edit the Scriptable Autosplitter you've added and select the .asl file.

### How to Use </br>
Be sure "Split" is checked, under the Script Path you selected. </br>

Select where you want to split in the "Advanced Settings" box. Splits 
do not depend on order and happen the ***first time*** a condition is met
only.

### How Splits Work </br>

* NG and NG+ Completion split on the next loading screen
after the credits roll.</br>
(Note: They don't split immediately on credits
in order to not race with the official IGT plugin reading the correct 
time from the save file when the credits begin)

* Event Flag Splits are triggered when an event flag is set.

* Bonfire Lit splits are triggered when a bonfire is lit.

* Zone Transition splits are triggered when the character moves from one
map to another (e.g., from Sen's Fortress to Anor Londo).

* Bounding Box splits are triggered if the player character is within the 
boundaries of a bounding box, or in other words, if the player character 
is roughly at a certain location. They are separated into three categories:
  
  * Current Location bounding boxes check if the player is at a certain location 
right now.
  
  * Upwarp bounding boxes check if the player is at a certain location within a 
short amount of time of loading in after a load screen.
  
  * Load-In Location bounding boxes are subtly different; they check during the 
loading screen if the player is going to spawn at a certain location.

Splits may also have several sub-options that dictate when the split occurs. These include:

* Split Immediately: splits the moment the split is triggered.

* Split On Next Quitout: waits until the next loading screen after a quitout to split.

* Split On Next Non-Quitout Loading Screen: wait until the next loading screen that wasn't preceded by a quitout to split.

* If you check none of these, it will default to splitting on the next load screen without checking for a quitout.
