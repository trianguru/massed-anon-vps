#!/bin/bash
exec docker run -it --rm \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -v "$HOME/kali-work":/work \
  my-kali:latest bash
