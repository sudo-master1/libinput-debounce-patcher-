New Command :-
git clone --depth 1 https://gitlab.freedesktop.org/libinput/libinput && cd ~/libinput && sed -i '417s/^[[:space:]]*'\''src\/libinput-plugin-button-debounce\.c'\'',/#&/' meson.build && sed -i '512s/^[[:space:]]*libinput_debounce_plugin(libinput);/\/\/&/' src/libinput-plugin.c && sed -i '34s/^#include "libinput-plugin-button-debounce.h"/\/\/&/' src/libinput-plugin.c && meson setup --prefix=/usr builddir/ --reconfigure --wipe && ninja -C builddir/ && sudo ninja -C builddir/ install && sudo systemd-hwdb update

what this does :-

1. clones the github repo
2. replaces the troubling lines whose files are in the sed cmd
3. after patches setups the build stuff with meson with the reconfigure and wipe cmds in it yes im lazy to remove the flags
4. uses ninja to set build dir and install
5. updates systemd-hwdb


   DO NOT USE THE SCRIPT ITS STILL IN DEVLOPMENT AND USES AI AND DOESNT WORK USE THE ABOVE COMMAND FOR NOW !!!



old :-DONT USE THIS THIS WONT WORK ANYMORE LATEST NON AI VER coming SOON
IF U ARE DESPERATE THERE IS A VERSION OF LIBINPUT BUT ITS OLD AND WILL PROBABLY BE AUTO UPDATED BY UR SYSTEM


temprory fix use at ur own risk after u patch u should probably look into info on ignoring upgrade of this important thing



cmd :- git clone --depth 1 https://gitlab.freedesktop.org/libinput/libinput && sed -i 's/const usec_t DEBOUNCE_TIMEOUT_BOUNCE = usec_from_millis(25);/const usec_t DEBOUNCE_TIMEOUT_BOUNCE = usec_from_millis(0);/' ~/libinput/src/libinput-plugin-button-debounce.c && sed -i 's/const usec_t DEBOUNCE_TIMEOUT_SPURIOUS = usec_from_millis(12);/const usec_t DEBOUNCE_TIMEOUT_SPURIOUS = usec_from_millis(0);/' ~/libinput/src/libinput-plugin-button-debounce.c && cd libinput && meson setup --prefix=/usr builddir/ && ninja -C builddir/ && sudo ninja -C builddir/ install && sudo systemd-hwdb update


thats one of the things that work working on disabling the plugin itself so it might not take ur 1 byte of ram

test sed command testing rn

cd ~/libinput
sed -i '417s/^[[:space:]]*'\''src\/libinput-plugin-button-debounce\.c'\'',/#&/' meson.build
sed -i '512s/^[[:space:]]*libinput_debounce_plugin(libinput);/\/\/&/' src/libinput-plugin.c
sed -i '34s/^#include "libinput-plugin-button-debounce.h"/\/\/&/' src/libinput-plugin.c



new cmd :- 
cd ~/libinput && sed -i '417s/^[[:space:]]*'\''src\/libinput-plugin-button-debounce\.c'\'',/#&/' meson.build && sed -i '512s/^[[:space:]]*libinput_debounce_plugin(libinput);/\/\/&/' src/libinput-plugin.c && sed -i '34s/^#include "libinput-plugin-button-debounce.h"/\/\/&/' src/libinput-plugin.c && meson setup --prefix=/usr builddir/ --reconfigure --wipe && ninja -C builddir/ && sudo ninja -C builddir/ install && sudo systemd-hwdb update


