---
title: "How to use Joplin Electron app on FreeBSD"
date: 2020-01-15T06:00:00+09:00
draft: true
tags: [ "application", "nodejs", "installation", "freebsd" ]
toc: true
---
This is a quick summary of how to use the latest Joplin Electron app on FreeBSD.

Please refer to [another article](/playing-with-bsd/application/joplin-on-freebsd) for my initial exploration of Joplin.

## Installing Joplin v1.0.177
1. Install dependencies such as Electron and Nodejs.  
   ```
   sudo pkg install electron6 node10 npm-node10 python
   ```
> The latest Joplin uses Electron7 but it's not yet available in the FreeBSD ports tree. Thus I use Electron6 here and haven't found any problem so far.  

2. Clone my forked version of Joplin and switch to electron_freebsd branch, which includes patches for FreeBSD.
   ```
   cd ~/tmp/or/somewhere
   git clone https://github.com/genneko/joplin.git
   cd joplin
   git checkout electron_freebsd
   ```

3. Build the desktop (Electron) application by mostly following the [original build instruction](https://github.com/laurent22/joplin/blob/master/BUILD.md#building-the-electron-application).
   ```
   npm install && cd Tools && npm install && cd ..
   npm run copyLib
   npm run tsc
   cd ElectronClient/app
   npm install
   ```

4. Now you can run the app by running the following commands.  
   ```
   electron .
   ```
   or
   ```
   ../joplin-desktop
   ```

## Workaround for weird character when entering text with a CJK input method
This issue is reported several times as below.
* [#1210](https://github.com/laurent22/joplin/issues/1210)
* [#1497](https://github.com/laurent22/joplin/issues/1497)
* [#1351](https://github.com/laurent22/joplin/issues/1351)

![Joplin LSEP](/images/howto-use-joplin-on-freebsd/JoplinLSEP.gif)

For users who have to use some "input method" for entering text, it is really annoying.  
But as [#1500](https://github.com/laurent22/joplin/issues/1500) says, it might be unfixable as it might be an Ace issue.

Luckily, you can still work around it by using a [special font](xxxx) which has only a single zero-width glyph for the weird character.

* If you are satisfied with the default editor font, just specify the special font in Option's "Editor Font".
  The weird character will be suppressed because it will be shown with the zero-width glyph in the specified custom font while other characters will be displayed with the default monospace font.

* If you are using a custom editor font, you cannot specify the special font in "Editor Font" because it overrides the custom font. ("Editor Font" can take only a single font name)  
  But if you have Joplin v1.0.176 or later, you can use "Custom stylesheet for Joplin-wide app styles" (userchrome.css) to work around this issue while you continue to use the custom editor font.  
  Just store the special font file somewhere and create "Custom stylesheet for Joplin-wide app styles" [^1] from Tools &gt; Options &gt; Appearance with the following content.
[^1]: The menu creates and edits ~/.config/joplin-desktop/userchrome.css.
  ```
  @font-face {
      font-family: NoLSEP;
      src: url(file:///home/username/share/fonts/NoLSEP.ttf);
  }
  
  div.ace_editor * {
      font-family: NoLSEP, IPAGothic, monospace !important;
  }
  ```

## References
* Joplin  
<https://joplinapp.org/>

* GitHub: laurent22/joplin  
<https://github.com/laurent22/joplin>

* GitHub: genneko/joplin  
<https://github.com/genneko/joplin>

* FreeBSD Forum: Electron for FreeBSD  
<https://forums.freebsd.org/threads/electron-for-freebsd.64103/>

* FreshPorts: devel/electron6  
<https://www.freshports.org/devel/electron6/>

## Revision History
* 2020-01-15: Created

