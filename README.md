DONT USE THIS THIS WONT WORK ANYMORE LATEST NON AI VER coming SOON
IF U ARE DESPERATE THERE IS A VERSION OF LIBINPUT BUT ITS OLD AND WILL PROBABLY BE AUTO UPDATED BY UR SYSTEM


temprory fix use at ur own risk after u patch u should probably look into info on ignoring upgrade of this important thing



cmd :- git clone --depth 1 https://gitlab.freedesktop.org/libinput/libinput && sed -i 's/const usec_t DEBOUNCE_TIMEOUT_BOUNCE = usec_from_millis(25);/const usec_t DEBOUNCE_TIMEOUT_BOUNCE = usec_from_millis(0);/' ~/libinput/src/libinput-plugin-button-debounce.c && sed -i 's/const usec_t DEBOUNCE_TIMEOUT_SPURIOUS = usec_from_millis(12);/const usec_t DEBOUNCE_TIMEOUT_SPURIOUS = usec_from_millis(0);/' ~/libinput/src/libinput-plugin-button-debounce.c && cd libinput && meson setup --prefix=/usr builddir/ && ninja -C builddir/ && sudo ninja -C builddir/ install && sudo systemd-hwdb update
