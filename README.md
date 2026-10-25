<!-- Screenshot -->
<div align="center">
    <img src="https://awesomewm.org/images/awesome-logo.svg">
</div>

<br>

<div align="center">
    <img src="https://github.com/user-attachments/assets/070a1bc2-ac43-4ef3-94b1-36fb3fe0f38a" alt="Rice Preview">
</div>

<br>
<br>

<a href="https://awesomewm.org/"><img alt="AwesomeWM Logo" height="160" align = "left" src="https://awesomewm.org/doc/api/images/AUTOGEN_wibox_logo_logo_and_name.svg"></a>
<b>  Aesthetic AwesomeWM Dotfiles for Termux  </b>

Welcome to my AwesomeWM configuration files! 

This is the vertical Rxyhn setup, which has been discontinued; I simply adapted it for Termux. 

Give it a try and enjoy!

Fyi, I use night colorscheme, and it's so beautiful.

These dotfiles are made with love, for sure.

<h2></h2><br>

**Here are some details about my setup:**

| Programs   | Using             |
| ---------- | ----------------- |
| WM         | awesome           |
| OS         | Termux            |
| Terminal   | xfce4-terminal    |
| Shell      | zsh               |
| Editor     | neovim            |
| Compositor | picom             |
| Launcher   | rofi              |

<h2></h2><br>

<details>
<summary><strong>S E T U P</strong></summary>

   > This is step-by-step how to install these dotfiles. Just [R.T.F.M](https://en.wikipedia.org/wiki/RTFM).

   1. Install dependencies 

         ```shell
            apt update && apt upgrade -y && pkg install x11-repo && pkg install git curl wget termux-api termux-x11-nightly curl
         ```

   
   3. Install AwesomeWM configuration Rxyhn files

      > Clone this repository

      ```shell
      git clone https://github.com/Keytaro2/Termux-Rxyhn.git
      cd Termux-Rxyhn
      ```

      > Execution permissions

      ```shell
      chmod +x install.sh && chmod +x start.sh 
      ```

      > Install

      ```shell
      sh install.sh &&  ~/./start-awesome.sh 
      ```


   5. Lastly, log out from your current desktop session and log in into AwesomeWM.

</details>

<br>

<details>
<summary><strong>F E A T U R E S</strong></summary>

<b>These are the features included in my AwesomeWM setups!</b>


   + Beautiful `colorscheme` ikr, named `night` and created by [ner0z](https://github.com/ner0z)
   + Aesthetic `Dashboard` ngl.
   + Custom mouse-friendly `ncmpcpp` UI with album art ofc.
      - <details>
         <summary>Preview</summary>

         *this is so aesthetic isn't it?*

         <div align="left">
         <img src="https://github.com/user-attachments/assets/6dd9d76a-f862-4cd5-9d58-88b2b04db447" width="500px" alt="ncmpcpp preview">
         </div>
         </details>
   + `Word Clock Lockscreen` with PAM Integration
      - <details>

         *A beautiful word clock is on the lockscreen!*

         <summary>Preview</summary>
         <div align="left">
         <img src="https://github.com/user-attachments/assets/42ae18ee-4465-451b-93fd-ea0b9ecb328f" width="500px" alt="word clock lockscreen preview">
         </div>
         </details>
   + Notification Center
   + Control Panel
   + ToDo Reminder
   + Battery Indicator
   + PopUp Notifications
   + Applications Launcher
   + Some Tooltip Widget
   + Hardware Monitor

</details>

<br>

<details>
<summary><strong>K E Y B I N D S</strong></summary>

I use <kbd>ctrl</kbd> as my main modifier.
also with <kbd>alt, shift, and ctrl</kbd>

**Keyboard**

| Keybind                                 | Action                                                    |
|-----------------------------------------|-----------------------------------------------------------|
| <kbd>ctrl + enter</kbd>                 | Spawn terminal                                            |
| <kbd>ctrl + w</kbd>                     | Spawn web browser                                         |
| <kbd>ctrl + x</kbd>                     | Spawn color picker                                        |
| <kbd>ctrl + f</kbd>                     | Spawn file manager                                        |
| <kbd>ctrl + d</kbd>                     | Launch applications launcher                              |
| <kbd>ctrl + shift + d</kbd>             | Toggle dashboard                                          |
| <kbd>alt + -</kbd>                      | Toggle control center (actions)                           |
| <kbd>alt + /</kbd>                      | Screenshot (also <kbd>Print</kbd>)                        |
| <kbd>ctrl + q</kbd>                     | Close client                                              |
| <kbd>ctrl + l</kbd>                     | Toggle lock screen                                        |
| <kbd>ctrl + [1-0]</kbd>                 | View tag AKA change workspace (for you i3/bsp folks)      |
| <kbd>ctrl + shift + [1-0]</kbd>         | Move focused client to tag                                |
| <kbd>ctrl + space</kbd>                 | Select next layout                                        |
| <kbd>ctrl + s</kbd>                     | Set tiling layout                                         |
| <kbd>ctrl + shift + s</kbd>             | Set floating layout                                       |
| <kbd>ctrl + alt + c</kbd>               | Center floating client                                    |
| <kbd>ctrl + shift + [arrow keys]</kbd>  | Change focus by direction                                 |
| <kbd>ctrl + [arrow keys]</kbd>          | Move floating window                                      |
| <kbd>alt + [arrow keys]</kbd>           | Resize floating window (→ ↓ grow, ← ↑ shrink)             |
| <kbd>ctrl + shift + f</kbd>             | Toggle fullscreen                                         |
| <kbd>ctrl + m</kbd>                     | Toggle maximize                                           |
| <kbd>ctrl + n</kbd>                     | Minimize                                                  |
| <kbd>ctrl + alt + n</kbd>               | Restore minimized                                         |
| <kbd>alt + tab</kbd>                    | Window switcher                                           |

<br>

**Mouse on the desktop**

| Mousebind          | Action                                     |
|--------------------|--------------------------------------------|
| `left click`       | Dismiss all notifications                  |
| `right click`      | App drawer                                 |
| `middle click`     | Toggle Dashboard                           |
| `scroll up/down`   | Cycle through tags                         |

<br>

**Mouse on windows**

| Mousebind                  | Action                                     |
|----------------------------|--------------------------------------------|
| `ctrl + left click drag`   | Move window                                |
| `ctrl + right click drag`  | Resize window                              |

*... And many many more! for more information check `awesome/configuration/keys.lua`*

</details>

<h2></h2><br>

**Acknowledgements**

   - **Credits**
      + [ner0z](https://github.com/ner0z)

   - **Special thanks to**
      + [ChocolateBread799](https://github.com/ChocolateBread799)
      + [JavaCafe01](https://github.com/JavaCafe01)

<h2></h2><br>

<p align="center"><a href="https://github.com/rxyhn/AwesomeWM-Dotfiles/blob/main/.github/LICENSE"><img src="https://img.shields.io/static/v1.svg?style=flat-square&label=License&message=GPL-3.0&logoColor=eceff4&logo=github&colorA=061115&colorB=67AFC1"/></a></p>
