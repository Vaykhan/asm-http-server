### simplistic web server written in x86_64 assembly

the project currently supports simple `get` and `post` requests for reading and writing small files.

however, it is pretty insecure as of now, since the requested directory has to be a full path, and because the server is usually run as root(for port 80 access), this makes it only feasible for local testing(and fun) purposes.

enjoy!
