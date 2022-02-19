# AnotherDarkSoulsAutosplitter
A Cursed Autosplitter for Dark Souls

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
