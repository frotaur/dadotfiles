I like colorful terminals, so please use colors when you can!

In general, I always use uv, so never use things like pip and stuff like that!
Usually, in the projects there will be a uv pyproject.toml, so you can just use uv run to run scripts. 
Additionally, there will often be a .env closeby, which usually has the necessary env-vars. I use direnv,
so you can use that to load them.
In rare cases where a pyproject.toml is not available (e.g. I do a quick script), you can fall back to the 'catch-all' venv which is located at
~/.penv. You can also double check its location by typing 'type penv'. This is the venv I use when I want to do
some quick stuff without bothering to setup uv.

Do not run any scripts you made, except if I explicitely ask. Usually, I would run script, and let you 
know the output. In some cases, you are allowed to test scripts, in which case I will explicitely tell you,
or give you the tag <goscript>. When running stuff, be very careful to usually never run stuff on GPU. Since
I'm on the cluster, we are forbidden using any GPU stuff except through slurm jobs.

Don't hesitate to be brutally honest with critics, and tell me if you think there is a better approach.

If I include <dtf> in my message, it means Dont Touch Files! If I include that, you are allowed to read
whatever your want, but don't write any code or anything else! I am just brainstorming.
