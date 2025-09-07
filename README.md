# massed-anon-vps

This repository contains a hardened Kali-in-Docker toolbox for Linux Mint (based on Ubuntu Jammy) running on a VPS.

The setup ensures that all traffic is routed through Tor as the first hop, followed by a dynamic chain of SOCKS/HTTP proxies, enforced by strict nftables rules to prevent leaks. It randomizes the network interface's MAC address, builds a custom Kali image with `kali-linux-default` and `kali-tools-top10`, and provides wrapper scripts for running commands through the Tor + proxy chain.

## Usage

1. Clone this repository and run `prestartup.sh`:

    ```bash
    git clone https://github.com/trianguru/massed-anon-vps.git
    cd massed-anon-vps
    ./prestartup.sh
    ```

    The script will prompt you to enter upstream proxy servers. It will then install Docker, build the Kali image, configure Tor, nftables and proxychains, randomize the MAC address and run an animated preflight check.

2. Start the Kali toolbox:

    ```bash
    ./run-kali.sh
    ```

3. Run commands through Tor and your proxies using the `pc` wrapper:

    ```bash
    pc curl https://icanhazip.com
    ```

4. Re-run the preflight check at any time:

    ```bash
    ./preflight_check.sh
    ```

All scripts are documented inline.
