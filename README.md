# libinput-debounce-patcher
BTW THIS HAS BEEN VIBE CODED but it works im trying to learn english and trying to improve this and unvibe code it but if u want u can use this IT WORKS THO

always download the highest v no and execute

note we only support fedora ubunu / debian and arch other os are not supported we are not liable if u brick ur system running this and have to reinstall ur linux distro

this script makes ur cps in arch go brr in cps

DISCLAIMER: I do NOT update the releases tab. Please kindly download the file from the source — the file is just a .sh script, not the actual source code!

So… I heard you want to play BedWars on your Linux machine, but your CPS is stuck at 6 or 7 max, while you can get 12 on Windows. I patched that, so you don’t have to go back to the prison of Windows just to play your favorite game - or for any other reason.

I used ChatGPT to check and troubleshoot the code. and and to check for spelling mistake

I live in India and English is not my native language, so please ignore any mistakes.

This is meant for Linux only.
How to Use:
1. Go to the directory where you downloaded this file in the terminal.

    cd Downloads

2. Make the file executable:

chmod +x libinput-patcher-v1.sh

3. Run the script with:

    sudo ./libinput-patcher-v1.sh



Common Mistakes:

1.You need to press y (lowercase) for now, because uppercase Y or n do not work.


how to turn it back into normal arch libinput 
u just need to reinstall libinput for ex :- in arch i can just type in terminal sudo pacman -S libinput 
to fix it 


btw chat gpt was used to correct my BAD spellings and get 2nd opiniun this part i aint going to send him to correct and this is the actuall un llm version :-


DISCLAMER :- i DO NOT update the release tab pls kindly download the file from source as it is not source it is just an .sh file !!

i heard u want to play bedwars in ur linux machine but ur cps be like 6 or 7 max u have 12 in windows i just patched that so u dont need to go to the prison of WINDOWS to play ur favorite game or ANY other reason

used chat gpt to check the code and trouble shute

i live in india and english is not my native lang so pls IGNORE spelling mistakes !!!!!

THIS IS MENT FOR LINUX

HOW TO USE

1. go to the dir where u downloaded this file in terminal by cd ex: cd Downloads
2. execute chmod +x libinput-patcher-v1.sh
3. execute sudo ./libinput-patcher-v1.sh

Coman Mistakes
1. U NEED TO PRESS y ONLY FOR NOW BECAUSE capital or n does not work




explaination of how the code works 

and this is the explanation (pls only read if u are technical)

1.    runs a small script to verify that u AGREE to patch it out and i am not responsible of it breaking or u brick Ur OS cuz u closed the install midway !

 2.   sets the directory where it downloads the source and builds to "/tmp/libinput-build-$$"

 3.   sets repository to download the code from too "https://gitlab.freedesktop.org/libinput/libinput.git"

 4.  sets a backup directory if something goes wrong

 5.   waits 5 seconds before activating the script so u still have chance to back out by clicking ctrl c

6.   sets bold text as log

 7.  sets yellow as warn

 8.  red as error

 9.   then states if it cant do something or there is an error it loads back the original libinput without making ur system not have a working mouse , keyboard etc works as a safety net as a backup and a last hope when something stops working (beware after reboot the tmp files will be deleted so do not turn of Ur PC in this process

 10.   after these conditions are set the code starts running first detects if your system has the supported ubuntu , fedora , arch package installers if it does not it returns as (Unsupported distro: no apt/dnf/pacman found. Install dependencies manually) here is the dependency list git build-essential meson ninja-build pkg-config libevdev-dev libwacom-dev libglib2.0-dev libudev-dev (note :- im too lazy to type their names like their actual project names so here is what it installs in ubuntu)

 11.   after install starts it pours all the libinput files into the tmp directory to be accessed when the install fails aka "/tmp/libinput-backup-$$" with config i think never tested

 12.   removes the libinput packages that were installed before patching and to avoid conflicts after checking what distro u use after packages are removed so are library

 13.   now it makes the work dir / "/tmp/libinput-build-$$" , and goes into it clones the libinput repo in "/tmp/libinput-build-$$" and the thing like the thing in the repo that caps the cps is src/libinput-plugin-button-debounce.c just finds that if the structure changes returns as "$FILE not found in repo (libinput changed structure?). Aborting." exit 1 there aka the file that defines the cap is changed to ( the line that makes it so in the code) to ms2us(0) from ms2us(25) and ms2us(12) deletes the build dir by rm -rf builddir and then executes meson setup builddir --prefix=/usr to make build folder and put the files in /usr than starts compiling with ninja then uses ninja to install builddir

  14.  after it does everything it gives a congratulations msg saying All done and then trys to restart but fails cuz i do not know how to fix :( and then waits for u to read that is finishes before giving the error to restart manually even if i tried everything


edit :- it works now i think :D


for more exact words / code of what it does pls kindly read the code
