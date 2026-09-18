#!/bin/bash
# 맥: 더블클릭하면 터미널이 열리며 설치된다.
cd "$(dirname "$0")" && bash ./install.sh
echo
read -n 1 -s -r -p "아무 키나 누르면 창을 닫을 수 있습니다."
echo
