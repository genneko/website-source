---
title: "How to use Joplin desktop app on FreeBSD"
date: 2020-01-15T20:26:00+09:00
lastmod: 2022-03-01T22:01:00+09:00
draft: false
tags: [ "application", "installation", "freebsd", "font" ]
toc: true
---
This is a quick note on how I build and use the latest Joplin desktop app on FreeBSD.

For my initial exploration of Joplin on FreeBSD, please refer to the [previous post](/playing-with-bsd/application/joplin-on-freebsd).

## Target Version
The current target version of this article is Joplin Desktop release v2.7.13 (Feb 2022).  
I confirmed that the app could be built using my fork at the tag [freebsd-v2.7.13](https://github.com/genneko/joplin/releases/tag/freebsd-v2.7.13).
![Joplin Version](/images/howto-use-joplin-on-freebsd/JoplinVersion.png)

## Building Joplin
I take the following steps to build Joplin desktop on my FreeBSD 12.3-RELEASE system (with XFCE4 desktop).

1. Install dependencies such as Electron and Nodejs.  
   As of 27 Feb 2022, all dependencies except electron13 can be installed from the FreeBSD's official packages.  
   (electron13 binary package is not available for FreeBSD 12/amd64 yet, while ones for FreeBSD 13/amd64 and some other architectures/versions are available.)
   ```
   sudo pkg install node npm-node python vips git rsync gnome-keyring gmake
   ```
   > **NOTE**  
   > To use the latest software versions, you might want to switch the package repository from 'quarterly' to 'latest'.  
   > Please refer to the [relevant section](https://www.freebsd.org/doc/handbook/pkgng-intro.html#quarterly-latest-branch) of the FreeBSD Handbook for the steps.

   For now, on 12.x you have to install electron13 by building its port.  
   The most basic steps to build the port are something like:  
   ```
   sudo portsnap fetch update
   cd /usr/ports/devel/electron13
   sudo make install
   ```
   But I'm using poudriere to build specific ports, actually.  
   Please note that building a huge software like electron with poudriere requires some care (Refer to <a href="https://twitter.com/genneko217/status/1452748669736787969">My tweet</a>).  

   Another option is to download and install a pre-built binary package from the pre-official repository at the following URL.  
   https://github.com/tagattie/FreeBSD-Electron

2. Clone my forked version of Joplin and switch to electron_freebsd branch, which includes some modifications for FreeBSD.
   ```
   cd ~/tmp/or/somewhere
   git clone https://github.com/genneko/joplin.git
   cd joplin
   git checkout electron_freebsd
   ```
   > **NOTE**  
   > If the head of the branch cannot be built (it occurs from time to time), please try the tagged version which I confirmed to be built.  
   > As of 27 Feb 2022, the latest confirmed tag is [freebsd-v2.7.13](https://github.com/genneko/joplin/releases/tag/freebsd-v2.7.13) and it can be checked out as follows:  
   > ```
   > git checkout freebsd-v2.7.13
   > ```

3. Make a small tweak to work around the [lzma-native build failure issue](https://github.com/addaleax/lzma-native/issues/98).  
   ```
   mkdir ~/bin
   ln -s /usr/local/bin/gmake ~/bin/make
   ```

4. Build the application by mostly following the [original build instruction](https://github.com/laurent22/joplin/blob/dev/BUILD.md#building-the-electron-application).
   ```
   PATH=~/bin:$PATH npm install
   cd packages/app-desktop
   npm run build
   ```
   > **NOTE**  
   > - ``PATH=~/bin:$PATH`` is prepended in order to use the tweak made in the previous step.  
   > - I use ``npm run build`` instead of ``npm start`` because it looks like the latter doesn't expect I'm using the globally installed electron.

4. Now you can run the desktop (Electron) app by running the following command  
   ```
   electron13 .
   ```
   or by running a script included in my fork
   ```
   ./joplin-desktop
   ```
   > **NOTE**  
   > When you encounter one of the following errors, please make sure that gnome-keyring's secret service is available on your system.
   > ```
   > Error: The name org.freedesktop.secrets was not provided by any .service files
   > Error: Unknown or unsupported transport 'disabled' for address 'disabled:
   > ```
   > You would be able to enable the service on your desktop environment's automatic startup settings.
   > For example, on XFCE4 it can be enabled by checking "Launch GNOME services on startup" on "Settings" > "Session and Startup" > "Advanced" tab.
   >
   > Or if you try to run Joplin on a headless system like jail with the help of SSH X11 forwarding (as I do for testing), the easiest way seems to be running it with [dbus-run-session(1)](https://www.freebsd.org/cgi/man.cgi?query=dbus-run-session(1)) like:
   > ```
   > dbus-run-session -- electron9 .
   > ```
   > ```
   > dbus-run-session -- ./joplin-desktop
   > ```


## Workaround for LSEP showing up in CJK input methods

_**NOTE:** The problem seems to have been resolved on Joplin v1.1.x or later with the editor component changed from Ace Editor to CodeMirror. Also, it is not FreeBSD-specific. But anyway, I wrote it down here for future reference._  

This issue was reported several times as below.
* [#1210](https://github.com/laurent22/joplin/issues/1210)
* [#1497](https://github.com/laurent22/joplin/issues/1497)
* [#1351](https://github.com/laurent22/joplin/issues/1351)

As pointed out in the issue [#1500](https://github.com/laurent22/joplin/issues/1500), it looks like unfixable as it might be an Ace Editor issue.  
But for users who have to use some "input method" for entering text, it is really annoying.

![Joplin LSEP](/images/howto-use-joplin-on-freebsd/JoplinLSEP.gif)

Fortunately, this issue can be worked around by using a [special font](/misc/NoLSEP.ttf) which has only a single zero-width glyph for the weird character (U+2028 Line Separator).

* If you are satisfied with the default editor font, you can just install the special font on your system and specify it in Tools &gt; Options &gt; Appearance &gt; Editor font family.  
  The weird character will be suppressed because it will be shown with the zero-width glyph in the specified font while other characters will be displayed with the default monospace font because they are not included in the special font.

* If you are using a custom editor font, you cannot specify the special font in "Editor font family" because it can take only a single font name thus overrides the custom font.  
  But if you have Joplin [v1.0.176](https://github.com/laurent22/joplin/releases/tag/v1.0.176) or later[^1], you can use the Joplin-wide stylesheet to work around this issue while you continue to use the custom editor font.  
  Just store the special font file somewhere and create Joplin-wide stylesheet from Tools &gt; Options &gt; Appearance &gt; Custom stylesheet for Joplin-wide app styles[^2].  
  For example, if you saved the special font as /home/username/share/fonts/NoLSEP.ttf and want to use IPAGothic as the custom editor font, the stylesheet should look like this[^3].  
  **Make sure to restart Joplin** after saving the stylesheet. Changes in the stylesheet have no effect until you restart Joplin. See the [official page](https://github.com/laurent22/joplin#custom-css) for more details.    
  ```
  @font-face {
      font-family: NoLSEP;
      src: url(file:///home/username/share/fonts/NoLSEP.ttf);
  }
  
  div.ace_editor * {
      font-family: NoLSEP, IPAGothic, monospace !important;
  }
  ```
  > **NOTE**  
  > For Windows, the font's path would be something like:
  > ```
  > file:///C:/Users/username/share/fonts/NoLSEP.ttf
  > ```

  > **NOTE**  
  > By default, Joplin uses the following style for its editor.
  > ```
  > .ace_editor * {
  >     font-family: monospace !important;
  > }
  > ```
  > If you specify "Editor font family", it goes like:
  > ```
  > .ace_editor * {
  >     font-family: FontYouSpecified, monospace !important;
  > }
  > ```
  > Because this style is placed AFTER the Joplin-wide styles, you have to give more score to the font-family spec in the Joplin-wide style.
  > I changed selector from '.ace_editor' to 'div.ace_editor' for this.
  
[^1]: Before the Joplin-wide stylesheet was implemented in v1.0.176, I had been using a [small patch](/misc/joplin_multi_editor_fonts.patch) to make "Editor font family" accept multiple fonts separated by comma, just for this purpose.
[^2]: The menu creates and edits ~/.config/joplin-desktop/userchrome.css.
[^3]: As NoLSEP font is used only for this specific purpose, I didn't want to install it in the system-wide directory such as /usr/local/share/fonts/TTF. So I put it under my home directory and defined @font-face rule to use it.

## References
* Joplin  
<https://joplinapp.org/>

* GitHub: laurent22/joplin  
<https://github.com/laurent22/joplin>

* GitHub: tagattie/FreeBSD-Electron  
<https://github.com/tagattie/FreeBSD-Electron>

* GitHub: addaleax/lzma-native  
<https://github.com/addaleax/lzma-native>

* GitHub: genneko/joplin  
<https://github.com/genneko/joplin>

* anopara: Ace EditorでL SEPという文字が出る  
<https://anopara.net/2018/01/19/ace-editor%E3%81%A7l-sep%E3%81%A8%E3%81%84%E3%81%86%E6%96%87%E5%AD%97%E3%81%8C%E5%87%BA%E3%82%8B/>

* RAWSEQ: Aceエディタ で日本語入力時のちらつきを解消する  
<https://qiita.com/RAWSEQ/items/7f9fc0fd4b3d572856ed>

## Revision History
* 2020-01-15: Create
* 2020-01-20: Update the target version to 1.0.178
* 2020-02-09: Update the target version to 1.0.184 (Use pre-official electron7 package)
* 2020-02-23: Update the target version to 1.0.185 (Build steps were changed)
* 2020-03-04: Update the target version to 1.0.187
* 2020-03-25: Add a note on Windows file path
* 2020-03-28: Add a note on restarting Joplin after editing the custom stylesheet.
* 2020-04-12: Update the target version to 1.0.199 and add a few notes
* 2020-04-12: Update the target version to 1.0.200.
* 2020-04-16: Update the target version to 1.0.201.
* 2020-05-02: Add a note on electron7-7.2.2.
* 2020-05-13: Update(Correction) to the note on electron7-7.2.2.
* 2020-06-24: Update the target version to 1.0.224 and do some cleanup.
* 2020-09-12: Update the target version to 1.0.233. Also add a note on 1.1.x in the LSEP/CJK section.
* 2020-12-03: Add notes on the recent versions.
* 2021-02-03: Update the target version to 1.7.10.
* 2021-06-30: Update the target version to 2.1.7.
* 2021-08-14: Update the target version to 2.2.7.
* 2021-08-18: Update the target version to 2.3.5.
* 2021-10-26: Update the target version to 2.4.12
* 2022-03-01: Update the target version to 2.7.13
