XTMax MS-DOS floppy image
=========================

xtmax360.img  - 360 KiB FAT12 (5.25" DD / many Gotek USB profiles)
This image is a driver/data disk, not a DOS system boot disk by default.

Build or refresh from the repository root:

  pip install -r scripts/requirements-floppy.txt
  python scripts/build_xtmax_floppy.py

720 KiB image:

  python scripts/build_xtmax_floppy.py --size 720 -o images/xtmax720.img

Drivers are downloaded from MicroCoreLabs GitHub (see ../software/README.md).

To make the image bootable, write DOS system files to it from DOS:

  SYS A:

XTSD.SYS notes:
- Use XTSD only when option ROM disk services are not used.
- For compatibility, prepare SD partitions as FAT16 (typically <= 32 MB).
- If needed, select a partition explicitly with CONFIG.SYS:
    DEVICE=A:\XTSD.SYS /P=1
