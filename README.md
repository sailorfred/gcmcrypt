# gcmcrypt
Command line AES256-GCM file encryption with 96 bit IV and 128 bit
authentication tag

The IV and authentication tag are stored in the output file, using this
format:

<first 12 bytes is the IV><ciphertext><last 16 bytes is authentication tag>

There is no additional authenticated data.

Installation:

For python 2.6+.  If you have 2.6, you must also install argparse:

pip install argparse

cryptography requires the ffi development libraries.  On Ubuntu, do:

sudo apt-get install libffi-dev

Then install cryptography via:

pip install -r requirements.txt

Usage:

Encryption:

gcmcrypt [ -d ] [ -k | -p ] [ -n ] <file>

For security against other users on the system using ps, stdin
must consist of the key or passphrase.  It will have whitespace
stripped from the end so that line terminators on different platforms
don't change the key.

-d or --decrypt says to decrypt the file instead of encrypting it

-k or --key says to get a hex encoded 32 byte (256 bit) key from stdin.
Be sure to use a cryptographically secure method for generating keys.

-p or --passphrase passphrase says to read a passphrase from stdin.
Trailing white space will be stripped from it, and it will be run through
PBKDF2 to provide the key.

-n or --noprompt doesn't prompt the user for the key or passphrase on
stderr.

Caveats:

Under python 2.x, two ^Ds are required to start the encryption.

In the interests of minimizing memory usage during decryption of large files,
unauthenticated plaintext is output to stdout.  Callers must verify a zero
(success) status code.
