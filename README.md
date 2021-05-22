# docker-proxyconfig

This container is part of my stack 'dave'

It's a small install of NGINX which serves a proxy.pac file for the network from a web server listening on port 81.

It informs clients of:
 - A list of local domains that clients should access directly
 - A list of remote domains that clients should access directly
 - A list of domains that should be not be contacted
 - To go direct for requests to single hostnames, non-routable networks, private IP ranges and localhost

The web server also has an /index.html which has links to download the certificates needed to install on clients

There is also a link to the proxy.pac file that is in use. It also has viewable lists of the local, direct and blocked websites.

Litecoin: LfmogjcqJXHnvqGLTYri5M8BofqqXQttk4