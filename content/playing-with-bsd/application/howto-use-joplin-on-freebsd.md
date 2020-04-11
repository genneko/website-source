---
title: "How to use Joplin desktop app on FreeBSD"
date: 2020-01-15T20:26:00+09:00
lastmod: 2020-04-12T08:39:00+09:00
draft: false
tags: [ "application", "installation", "freebsd", "font" ]
toc: true
---
This is a quick note on how I build and use the latest Joplin desktop app on FreeBSD.

For my initial exploration of Joplin on FreeBSD, please refer to the [previous post](/playing-with-bsd/application/joplin-on-freebsd).

## Target Version
The current target version of this article is Joplin Electron release v1.0.199 (Apr 2020).  
I confirmed that the app could be built using my fork at the tag [freebsd-20200412](https://github.com/genneko/joplin/releases/tag/freebsd-20200412).
![Joplin Version](/images/howto-use-joplin-on-freebsd/JoplinVersion.png)

## Building Joplin
I take the following steps to build Joplin desktop on my FreeBSD 12.1-RELEASE system (with XFCE4 desktop).

1. Install dependencies such as Electron and Nodejs.  
   Now all dependencies can be installed from the FreeBSD's official packages.  
   ```
   sudo pkg install electron7 node12 npm-node12 python vips
   ```
   > **NOTE**  
   > As the electron7 port is pretty new, you might have to switch the package repository from 'quarterly' to 'latest' to install electron7.  
   > Please refer to the [relevant section](https://www.freebsd.org/doc/handbook/pkgng-intro.html#quarterly-latest-branch) of the FreeBSD Handbook.
   
   Then I created symbolic links for compatibility.  
   ```
   cd /usr/local/bin
   sudo ln -s electron7 electron
   cd /usr/local/share
   sudo ln -s electron7 electron
   ```

2. Clone my forked version of Joplin and switch to electron_freebsd branch, which includes some modifications for FreeBSD.
   ```
   cd ~/tmp/or/somewhere
   git clone https://github.com/genneko/joplin.git
   cd joplin
   git checkout electron_freebsd
   ```
   > **NOTE**  
   > If the head of the branch cannot be built (it occurs from time to time), please try the tagged version which I confirmed to be built.  
   > As of 12 April 2020, the latest confirmed tag is [freebsd-20200412](https://github.com/genneko/joplin/releases/tag/freebsd-20200412) and it can be checked out as follows:  
   > ```
   > git checkout freebsd-20200412
   > ```

3. Build the desktop (Electron) application by mostly following the [original build instruction](https://github.com/laurent22/joplin/blob/master/BUILD.md#building-the-electron-application).
   ```
   npm install
   cd ElectronClient
   npm run build
   ```
   > I use ``npm run build`` instead of ``npm run start`` because it looks like the latter doesn't expect I'm using the globally installed electron.

4. Now you can run the app by running the following command  
   ```
   electron .
   ```
   or by running a script included in my fork
   ```
   ./joplin-desktop
   ```

## Workaround for LSEP showing up in CJK input methods

_**NOTE:** This is not FreeBSD-specific. But anyway, I wrote it down here for future reference._  

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
  > NOTE  
  > For Windows, the font's path would be something like:
  > ```
  > file:///C:/Users/username/share/fonts/NoLSEP.ttf
  > ```

  > NOTE  
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

* GitHub: genneko/joplin  
<https://github.com/genneko/joplin>

* anopara: Ace EditorでL SEPという文字が出る  
<https://anopara.net/2018/01/19/ace-editor%E3%81%A7l-sep%E3%81%A8%E3%81%84%E3%81%86%E6%96%87%E5%AD%97%E3%81%8C%E5%87%BA%E3%82%8B/>

* RAWSEQ: Aceエディタ で日本語入力時のちらつきを解消する  
<https://qiita.com/RAWSEQ/items/7f9fc0fd4b3d572856ed>

## Revision History
* 2020-01-15: Created
* 2020-01-20: Updated the target version to 1.0.178
* 2020-02-09: Updated the target version to 1.0.184 (Use pre-official electron7 package)
* 2020-02-23: Updated the target version to 1.0.185 (Build steps were changed)
* 2020-03-04: Updated the target version to 1.0.187
* 2020-03-25: Add a note on Windows file path
* 2020-03-28: Add a note on restarting Joplin after editing the custom stylesheet.
* 2020-04-12: Updated the target version to 1.0.199 and add a few notes
