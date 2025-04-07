This is a powershell script which converts "ASC" files created by a "Bed of nails" PCB testing machine.
It was developed for the many leaked files of obsolete ASUS motherboards. With minor tweaks, it could work on others if they exist.
These are usually 5 files.
Format.asc
Parts.asc
Nails.asc
Pins.asc
Nets.asc

It creates crude KICAD PCB, footprint, symbols, and schematic output.
It does not, and cannot add traces because that data does not exist.

Parts of the code are redundant, unoptimised, or otherwise not great, but it works, and it's not too slow, so I chose to leave it at that.

To use:
Simply drop in the relevant folder containing the ASCs and run from the powershell commandline.

It is not in active development.
