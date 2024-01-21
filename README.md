Szl is a tiny terminal interface for chatting with llms for linux / macOS. It offers some nice improvements to the user interface for python-tgpt and offers simple local chat management. As of today, it depends on two main packages in addition to GNU core tools:
1. python-tgpt (See https://github.com/Simatwa/python-tgpt ) [version 0.2.2]
2. fzf [version 0.44.1]

Note: Some users have reported errors running the script with bash on MacOS. Zsh seems to work fine. 
So on macOS run as:
zsh szl.sh

Also, there are some inherent differences in how bsd handles core utilities like sed. The places where there are differences have been mentioned in the script and have been commented out. If you are a macOS user experiencing issues uncomment the macOS lines and comment out the Linux ones.

Feel free to report bugs and raise issues.
