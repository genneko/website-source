---
title: "Using Joplin Terminal Application and Web Clipper on FreeBSD"
date: 2019-06-20T17:30:00+09:00
draft: true
tags: [ "application", "nodejs", "installation", "freebsd" ]
toc: true
---
I've been using Evernote since April 2011, a month after the M9.0 earthquake.

Although there were times the app got disappointing updates or the service was unexpectedly interrupted, it had been a great app/service and hopefully it is and it will be.  

Looking at the sorted note list on its web application, my first note has a date of 2011-04-24 and is about the Android browser and local file. That was when I bought my first smartphone and played with Android 2.x running on it, I remember.

Since then, the number of notes has grown up to around 20000 and without doubt, it had been one of the most frequently used applications along with web browsers, email clients and UNIX tools such as shells, ssh, rsync and vim ... until last week. 

There might be something wrong with the recent update of Android app. It's draggingly slow and drains the battery all the time. My phone became unusually hot, so I had no other choice than to uninstall it and start looking for alternatives.

To be clear, Windows and Web apps continue to work fine.  
But as my daily usecase is as follows and "Evernote for Web" cannot be used on Android browsers, I effectively lost access to my notes on mobile environemnts. That's a huge problem.

- On PCs
  - using "Evernote for Web" to edit/view notes and clip web pages  
  I only use "Evernote for Windows" for sync and backup (export) notes to the local drive.

- On mobile devices
  - using "Evernote for Android" to view and occasionally add/edit notes and clip web pages

That is where [Joplin](https://joplinapp.org) comes in.  
It's an open source note-taking application which supports multiple platforms and it has been drawing my interest for a while (according to my note it's since December 2017).

While an update is still not available for Evernote Android app, I decided to try out Joplin on Android, Windows, Linux ... and FreeBSD, my favorite operating system.

As this blog title has 'BSD', I will focus on installing Joplin on FreeBSD environments in thie article.  
I'm not going to explain how to configure hosts, apps and a sync target (WebDAV server in my case) here.
 
## Which Types of Applications to Use?
[Joplin website](https://joplinapp.org#installation) says three types of applications are available and each one supports the following platforms.

- Desktop (Electron) Application - runs on Windows, MacOS and Linux.
- Mobile (React Native) Application - runs on Android and iOS.
- Terminal (Node.js) Application - runs on Windows, MacOS and Linux

At first glance, none of them seem to support FreeBSD.  
It looks so hard to build the desktop app, though I recently heard about the progress of Electron on FreeBSD.  
On the other hand, the terminal app seems to have at least minimal support for FreeBSD as the [issue #867](https://github.com/laurent22/joplin/issues/867) indicates, so I began with the terminal app.

There are also the following add-on and third-party tools.

- [Web Clipper Browser Extension](https://github.com/laurent22/joplin/blob/master/readme/clipper.md) - for Chrome and Firefox. use the desktop app's Web Clipper API service
- [joplin-web](https://github.com/foxmask/joplin-web) - Python-based web frontend. use the desktop app's Web Clipper API service
- [perl-Joplin-API](https://github.com/sciurius/perl-Joplin-API) - Perl module to access Web Clipper API

Basically all of them require the desktop app running on the same host because they interact with the API service provided by the desktop app.  
But it seems possible to use the terminal app instead if you build it with support code in an experimental branch. So I will try them later, too. 

## Install Terminal Application on FreeBSD
Okay, let's install the terminal app on FreeBSD.

There's two ways to install the app.  
One is to install it with npm (Node Package Manager) and the other is to build it from its source code.

For each method, I describe the steps taken to install and run the terminal app on FreeBSD 11.3-BETA3 and 12.0 (both on amd64 architecture).  

### Notes
- Here I assume that you use sudo to perform privileged operations and your FreeBSD system has basic packages such as bash, rsync, python, curl and gnupg already installed. If not, please install them by running something like ``pkg install bash rsync python curl gnupg``.

- If you get errors like 'python: not found' during an installation process even if you have python2.7 or python3.6 installed, please install 'python' package as well.

- I use node8 and npm-node8 packages. I also confirmed that node10 and npm-node10 packages also work.

- build.sh and other scripts have a hard-coded path /bin/bash on SheBang line, but on FreeBSD, packaged bash is installed in /usr/local/bin. So I run them like ``bash ./build.sh``.

### Install the App using npm
If you want to install and run the plain Joplin terminal application, this is the easiest way.

Basically, you just have to follow the instructions in "Terminal application" / "Linux or Windows (via WSL)" section on the [Joplin website](https://joplinapp.org/#terminal-application).

1. Install dependencies.  
pkgconf and vips are required for installing node-gyp.  
    ```
    sudo pkg install node8 npm-node8 pkgconf vips
    sudo npm install -g node-gyp
    ```

2. Install joplin terminal application.  
    ```
    NPM_CONFIG_PREFIX=~/.joplin-bin npm install -g joplin
    sudo ln -s ~/.joplin-bin/bin/joplin /usr/local/bin/joplin
    ```

3. Start the terminal app by running the following command.
    ```
    joplin
    ```

4. Yeah. I got it working!  
![Joplin Terminal App](/images/joplin-on-freebsd/joplin-terminal-app.png)  
Now you can setup synchronization with built-in :config command.  
For example, you can setup synchronization to your WebDAV folder like:
```
:config sync.target 6
:config sync.6.path https://yourserver.example.com/your/dav/folder
:config sync.6.username your_username
:config sync.6.password your_password
```
Please refer to [Terminal Application Documentation](https://joplinapp.org/terminal/) for more information.  
By the way, you can quit the app by typing ``:exit`` and press Enter key.

### Build the App from Source
If you want to modify or use experimental branch of the terminal application, this is the way to go.

Basically, you can follow the steps described in ["Linux and Windows (WSL) dependencies"](https://github.com/laurent22/joplin/blob/master/BUILD.md#linux-and-windows-wsl-dependencies), ["Building the tools"](https://github.com/laurent22/joplin/blob/master/BUILD.md#building-the-tools) and ["Building the Terminal application"](https://github.com/laurent22/joplin/blob/master/BUILD.md#building-the-terminal-application) sections on the [Build instruction page](https://github.com/laurent22/joplin/blob/master/BUILD.md).

1. Install dependencies.  
pkgconf and vips are required for installing node-gyp.  
You need yarn in addition to the ones required for npm installation.  
    ```
    sudo pkg install node8 npm-node8 pkgconf vips
    sudo npm install -g node-gyp
    cd ~/tmp/or/somewhre
    fetch https://yarnpkg.com/install.sh
    less install.sh
    sh ./install.sh
    ```

2. Get (clone) the source from GitHub.  
    ```
    git clone https://github.com/laurent22/joplin.git
    ```

3. Build the tools.  
    ```
    cd joplin/Tools
    npm install
    ```

4. Build the terminal application (aka CLI client).  

    ```
    cd ../CliClient
    npm install
    bash ./build.sh
    rsync --delete -aP ../ReactNativeClient/locales/ build/locales/
    sudo ln -s $(pwd)/build/main.js /usr/local/bin/joplin
    ```

5. Start the terminal app by running the following command.
    ```
    joplin
    ```

6. Yeah. I got it working!  
Please refer to [Terminal Application Documentation](https://joplinapp.org/terminal/) for more.  
By the way, you can quit the app by typing ``:exit`` and press Enter key.

## Web Clipper
[Joplin Web Clipper](https://github.com/laurent22/joplin/blob/master/readme/clipper.md) is a web browser extension which lets you clip web pages you are viewing, just like Evernote Web Clipper.

It's easy to install it on supported browsers, i.e. Chrome and Firefox. Just search "Joplin Web Clipper" on Chrome Web Store or Firefox's Add-ons Manager page and add it to the browser. Then you can see the Joplin ("J") button on your toolbar.

Whenever you want to clip(save) a web page you are currently visiting, just click "J" icon, select how/what/where to clip and click "Confirm".

But on your FreeBSD machine on which you just installed the terminal app, you get an error "Could not find clipper service".

As I mentioned earlier, API service must be running on the same host where you use your browser. But the service can be only provided by the desktop application, which I cannot build on FreeBSD (yet). So what can I do?

Fortunately, there was already a discussion on [Joplin Forum](https://discourse.joplinapp.org/t/web-clipper-api-for-cli/725/11) about implementing API service on the terminal app and there is also an experimental ['headless-server' branch](https://github.com/laurent22/joplin/tree/headless-server) in the repository.

That information made me try to build the terminal app with API server functionality.

### Build the Terminal App with Headless Support
This is really a quick and dirty solution just for me and I will never recommend it to anyone else.

But anyway, I wanted to use Web Clipper on FreeBSD (and I also want to use Joplin behind a HTTP proxy) so I forked Joplin repo on GitHub and created a personal branch 'headless_proxy' from master, where I merged upstream's headless-server and proxy_test branches with some dirty modifications to make it slightly more headless.

Installation steps are exactly the same as [Build the Terminal App from Source](#build-the-app-from-source) except the github repository to clone and the branch to use.

So please refer to [the section](#build-the-app-from-source) and replace the step 2 with the following command lines.

```
git clone https://github.com/genneko/joplin.git
cd joplin
git checkout -b headless-proxy origin/headless_proxy
```

This custom terminal app can be run the same as the original one.

To start Web Clipper API service, type the following command in the terminal app.
```
:server start
```

To stop the service, run the following command in the app or exit the app.
```
:server stop
```

With my dirty modifications, you can also run the service without UI by running the following command on your shell.
```
joplin server start
```

Now you can use Web Clipper extension on your FreeBSD machine!
![Web Clipper runs on FreeBSD](/images/joplin-on-freebsd/webclipper-on-freebsd.png)

## Joplin Web
Because I've been mainly using Evernote on its Web application, it is really nice to have a web UI for Joplin too.

Again fortunately, there's a nice third-party web frontend [Joplin Web](https://github.com/foxmask/joplin-web) on GitHub. Although it looks like a WIP/experimental project, I gave it a try.

1. Firstly, you need python36 and py36-sqlite3 packages.

    ```
    sudo pkg install py36-sqlite3
    ```

2. Install Joplin Web by following the instructions on its [webpage](https://github.com/foxmask/joplin-web).

    ```
    cd
    python3.6 -m venv .joplin-web
    cd .joplin-web/
    source bin/activate
    git clone https://github.com/foxmask/joplin-web
    cd joplin-web/
    pip install -r requirements.txt
    ```

3. Edit a config file.
    ```
    cp joplin_web/env.sample joplin_web/.env
    vi joplin_web/.env
    ```

    [joplin_web/.env]
    ```
    ...
    JOPLIN_PATH='/home/genneko/.config/joplin/'
    JOPLIN_PROFILE_PATH='/home/genneko/.config/joplin/'
    JOPLIN_TOKEN='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
    API_USE_JOPLIN_WEBCLIPPER=True
    ```

    JOPLIN_TOKEN can be get by running the following query on the joplin terminal app's database file.
    ```
    sqlite3 ~/.config/joplin/database.sqlite "select value from settings where key = 'api.token"
    ```

4. Prepare a database.  
This creates joplin_web.sqlite3 file in the current directory.  
    ```
    python manage.py migrate
    ```

5. Run the server.  
    ```
    python manage.py runserver 0.0.0.0:8001
    ```
    
6. Now you can point your web browser to port 8001 and see the notes on your Joplin installation.  
![Joplin Web](/images/joplin-on-freebsd/joplin-web.png)

## REST API and a Handy Perl Module
Joplin Web Clipper Service provides a clean and well-documented [REST API](https://joplinapp.org/api/).

For example, you can get a list of notebooks by using the following command line.  
([jq](https://stedolan.github.io/jq/) is a powerful command-line JSON processor and can be installed from package)
```
curl -s http://localhost:41184/folders | jq
[
  {
    "id": "395a8d2573aa46849e67d06d69b9b692",
    "parent_id": "",
    "title": "NewBook",
    "type_": 2
  },
  {
    "id": "69a54d3a9b3541d291c75d429e707e02",
    "parent_id": "",
    "title": "Welcome! (CLI)",
    "type_": 2
  }
]
```

I first thought that I could possibly write yet another CLI client in /bin/sh but then I found that there's a [very handy perl module](https://github.com/sciurius/perl-Joplin-API) to access the API.

Here are the steps I took to install and get a feel of it.

1. Install dependencies.  
    ```
    sudo pkg install p5-JSON p5-libwww
    ```

2. Get (clone) the source from GitHub.  
    ```
    git clone https://github.com/sciurius/perl-Joplin-API.git
    ```

3. Build and install the module to ~/local/lib/perl5/site_perl.
    ```
    cd perl-Joplin-API
    mkdir ~/local
    perl Makefile.PL PREFIX=~/local
    make
    make install
    ```

4. Try to run the similar operation with perl.
    ```
    cat | perl -Mlib=$HOME/local/lib/perl5/site_perl -MJoplin
    $j = Joplin->connect(server=>"http://localhost:41184", apikey=>"");
    $books = $j->find_folders();
    for my $book (@$books){
        printf("%s: %s\n", @$book{'title', 'id'});
    }
    ^D
    NewBook: 395a8d2573aa46849e67d06d69b9b692
    Welcome! (CLI): 69a54d3a9b3541d291c75d429e707e02
    ```

That's so great!

## References
* Joplin  
<https://joplinapp.org/>

* GitHub: laurent22/joplin  
<https://github.com/laurent22/joplin>

* GitHub: foxmask/joplin-web  
<https://github.com/foxmask/joplin-web>

* GitHub: sciurius/perl-Joplin-API  
<https://github.com/sciurius/perl-Joplin-API>



