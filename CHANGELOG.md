v1.1alpha:

- Increased number of Tox nodes and added the ability to add user nodes in .json format.
- Increased response time of the chat area when you open the keyboard.
- Fixed bug when the application freezes when it's opened from the background.
- Fixed bug with missing line breaks after quotes in messages.
- Fixed bug that prevented editing text in the chat area by sending text cursor to the end of line.
- Added confirmation dialog when deleting a friend from the contact list.
- Added ability to delete chat history for contacts.
- Added ability to enable or disable saving chat to history.
- Added ability to change noSpam value (toxcore).

v1.2alpha

- Qt version updated from 5.13.2 to 5.14.1.
- Added support for x86 architecture.
- Fixed bug: QR code image doesn't refresh upon NoSpam change.
- Added profile selection menu and ability to create a new profile.
- Added ability to delete profiles to settings menu.
- Added profile and chat history encryption if password is set.
- Added new UI icons.
- The application will now work on Android 5 (API 21) and above.

v1.2.1alpha

- Fixed bug: the first received friend request is visible in status bar
- Added a timer to resume connection to Tox nodes if it has been lost.
- Added code to fix graphical issues with bug #6 (https://gitlab.com/Monsterovich/protox/-/issues/6)

v1.3alpha

- Improved profile saving.
- Disable drag & drop if friend list has only one item.
- Fixed a graphical bug with nickname updates affecting request entries.
- Show bootstrapping status on reconnection.
- Fixed a memory leak with password key.
- Improved login menu fade animation.
- Fixed a minor bug with user selection: no user is selected when you logout with clean profile.
- Improved font scaling.
- Added scrollbar to chat area.
- Added validators to nickname, status message, toxId, friend request message fields.
- Improved the look of profile menu.
- Show the number of available tox nodes in .json.

v1.4alpha

- Added translation support to the application
- Added Russian translation
- Added support for landscape orientation
- Added support for fake offline-messages
- Added "Auto-away after" feature
- Added ability to remove messages from history
- Improved the "Keep chat history" feature: the application will now keep messages and remove them when the application is closed
- Improved the look of the application on large screens
- Redesigned login menu and added more cool backgrounds!
- Fixed a problem with loading wrong noSpam on x86 architecture
- Newlines in nickname and status messages will now be replaced by spaces
- Improved message formatting regExp
- Added a new splash screen
- Improved message entry field: multi-line handling on various orientations
- Improved profile saving/loading performance
- Improved the look of the message cloud

v1.4.1alpha

- Fixed issues with bootstrapping

v1.4.2alpha

- Improved the quality of small UI items
- Redesigned message typing area
- Many UI improvements: main window, login menu, settings menu
- Message cloud width will now be correct on screen orientation change
- Improved validator on Tox ID field
- Updated Russian translation

v1.5beta_pre

- Added file transfers in both directions.
- Added buttons to chat typing area for file transfers.
- Added notifications for file transfers.
- Added "Change downloads folder" button to settings menu. (the default folder is Android downloads folder).
- Main window and message list were reworked which fixed many bugs.
- Added "Public Key" entry to friend information dialog.
- Some menus will now fill the screen width.
- Fixed bug: message timestamp disappears immediately when the message. cloud becomes invisible while scrolling.
- Fixed bug: flickering issues when using auto-login.
- Added logging feature (protox.log file to application directory).
- Updated Russian translation.
- Updated toxcore version to v0.2.12.

v1.5beta

- Added avatars.
- Added threads for file transfers which fixed many bugs in UI and improved performance (ex. progress bar).
- Reworked login window UI.
- Fixed bug: notification sound and vibration constantly repeats while file is downloading.
- Fixed bugs: many regressions with typing text and scrolling to end which weren't present in v1.4.2.
- Generally improved message scrolling.
- Fixed bug (partially): can't send files from "Downloads" (Android's native DownloadManager, not downloads folder) and it crashes on Android 10.
- Reworked image preview UI in file messages.
- Reworked file transfer states: file transfer status text will appear when transfer is paused remotely, remote pause no longer breaks UI when transfer is paused locally. 
- Reworked colors in the application.
- Added multiple image selection (if supported on device).
- Updated Russian translation.

v1.5.1beta

- Fixed bug: user can't accept friend requests because Tox Id is broken on client's side (https://gitlab.com/Monsterovich/protox/-/issues/7).
- Improved file threads code to resolve potential thread crashes.

v1.6beta

- Added proxy support.
- Added feature: history loading during scrolling.
- Added custom nicknames.
- Fixed bug: TCP mode (when "Enable UDP" is off) didn't always work.
- Added a smooth transition animation for "friend is typing" indicator and fixed a few issues with it.
- Fixed wrong implementation of toxcore timer.
- Added feature: save last selected profile to config upon selection.
- Fixed bug: file messages were not treated as temporary messages when "Keep chat history" is disabled.
- Added ability to copy friend properties to clipboard in friend info menu.
- Added animations to some menus.
- Improved file notifications.
- Added file transfer auto-accept feature.
- Improved login performance.
- Inline image preview height is now limited to prevent overly tall images from disrupting the chat log. Images that are too tall are cut off so that the center is visible, with gradients indicating that the image is too tall.
- Added support for sending multiple files (qt5.15.1 build only).
- Added animated dots to "friend is typing" indicator.
- Added a "reply" button to message notifications, allowing to write and send a response right in the notification.
- Added ability to scan a QR code with an external application to fill the Tox ID field without typing.
- Fixed UI lags when a user recieves file(s) at high speed.

v1.6.1beta

- Fixed bug: file transfers no longer randomly get stuck after reaching high speeds. This was caused by an unhandled file chunk send error due to limited size of outgoing packet queue. Fixed by adding resending logic for this case.
- Added support for "/me" command.
- Fixed a small issue with typing text which remained after friend change in rare cases.
- Fixed bug: custom nicknames are ignored on friend nickname change.
- Added Brazilian Portuguese translation.
- Added animation to status indicator button.

v1.6.2beta

- Fixed bug: notification don't work on Android O and higher.
- Reworked notifications, which resolved many issues with them and generally improved notification behavior.

v1.6.3beta

- Added a persistent notification that shows connection status to the Tox network.
- Updated Qt version from 5.14.2 to 5.15.2. It's now possible to select multiple files in the file selection dialog.
- Fixed crashes and various issues on Android 10, including issues with file access on Lineage OS (Android 10).
- Added ability to import Tox profiles into the application without copying them to the application folder.
- Fixed possible crashes when canceling file transfers.
- Message history now scrolls to the end after replying from a notification.
- The "Enable UDP" option is now off by default for new users.
- Fixed a possible crash in file notifications when a file transfer finishes.
- Added ability to view the file when a user clicks on the file notification.

v1.6.4beta

- Added workaround for Qt bug: application window does not cover entire screen on some android devices.
- Fixed application crash when no app store for downloading barcode scanner is found, in that case, the application opens a link in web browser instead.
- Reworked the algorithm for scrolling messages to end.
- Changed profile import icon.
