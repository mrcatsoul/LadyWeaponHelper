A relatively simple script (addon) for automatic removal and equipping of weapons on the boss Lady Deathwhisper without using DBM and equipment sets for WoW 3.3.5.

It works independently of DBM and, unlike DBM, there is no need to add an equipment set for equipping, which saves a slot. The script remembers the weapon by its link and the slot it was in and equips it in the same order. I wrote it because I don't use DBM, or if I do, it's the classic version from 2010 with minimal settings, which has everything I need and minimal memory consumption.

Initially, it was made for personal use, but I decided to share it, so I added some settings. The option to remove by timer is enabled by default, which is necessary in case the ping doesn't allow removing by shout/cast (there is a temporary window between `CHAT_MSG_MONSTER_YELL` \ `SPELL_CAST_SUCCESS` and `SPELL_AURA_APPLIED`). However, there is a problem with the timer: Lady doesn't always cast MC precisely according to it, especially in the second phase; she may give it with a delay. I don't know how to counter this, so with this option enabled, there may be downtime, even for a few seconds without a weapon in hand.

At the time of writing, it has only been tested in spectate mode, not in live combat. Therefore, if anyone uses it, enable Lua error display and report if anything is wrong.

![image](https://i.imgur.com/j0n0HMm.jpeg)

Small demo: https://www.youtube.com/watch?v=ABbYSseytvQ
