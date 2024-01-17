szl is a tiny terminal interface for chatting with llms for linux. It offers some nice improvements to the user interface for python-tgpt and offers simple chat management. As of today it depends on two main packages in addition to GNU core tools:
1. python-tgpt (See https://github.com/Simatwa/python-tgpt ) [version 0.2.2]
2. fzf [version 0.44.1]

Note: Some users have reported errors running the script with bash on MacOS. There are some inherent differences in how bsd handles core utilities like sed. zsh seems to works fine. Feel free to report bugs and raise issues.
