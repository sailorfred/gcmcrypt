#!/usr/bin/env python

import argparse
import binascii
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers import (
    Cipher, algorithms, modes)
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import os
import sys


def read_key(noprompt=False):
    key = b''
    if not noprompt:
        os.write(2, b'Enter key or passphrase, ending with EOF: ')
    for l in sys.stdin:
        l = l.rstrip()
        if sys.version_info[0] > 2:  # bytes for python 3
            l = l.encode('latin-1')
        key += l

    return key


def encrypt(key, f, outfd, bytes, key_is_passphrase=True):
    rnd = os.urandom(bytes)  # Either salt or iv, depending on key_is_passphrase
    os.write(outfd, rnd)  # Write to fd for Python 2, 3 portability
    if key_is_passphrase:
        iv, key = iv_and_key_from_salt(rnd, key)
    else:
        iv = rnd
    # Construct an AES-GCM Cipher object with the given key and a
    # randomly generated IV.
    encryptor = Cipher(
        algorithms.AES(key),
        modes.GCM(iv),
        backend=default_backend()).encryptor()

    # associated_data will be authenticated but not encrypted,
    # it must also be passed in on decryption.
    encryptor.authenticate_additional_data(b'')

    while True:
        line = f.read(65536)
        if len(line) == 0:  # Finished
            os.write(outfd, encryptor.finalize() + encryptor.tag)
            break
        os.write(outfd, encryptor.update(line))


def decrypt(iv, key, f, outfd):
    # Check file has enough data to be encrypted
    f.seek(0, 2)
    assert f.tell() >= (len(iv) + 16), 'File too small to have been encrypted by gcmcrypt'
    # Grab the tag from the end of the file
    f.seek(-16, 2)
    size = f.tell() - len(iv)  # Size of ciphertext
    tag = f.read(16)
    assert len(tag) == 16
    f.seek(len(iv), 0)  # Back to start of ciphertext
    # Cipher object with tag, and empty associated data
    decryptor = Cipher(
        algorithms.AES(key),
        modes.GCM(iv, tag),
        backend=default_backend()).decryptor()
    decryptor.authenticate_additional_data(b'')

    while True:
        if size > 0:
            line = f.read(min(65536, size))
            size -= len(line)
        else:
            line = b''
        if len(line) == 0:  # Finished
            os.write(outfd, decryptor.finalize())
            break
        os.write(outfd, decryptor.update(line))


def iv_and_key_from_salt(salt, passphrase):
    default_backend()
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=len(salt) + 32,
        salt=salt,
        iterations=100000,
        backend=default_backend())
    h = kdf.derive(passphrase)

    return h[:len(salt)], h[len(salt):]

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-b', '--bits',
                        help='Number of bits in IV or salt, defaults to 96',
                        type=int, default=96)
    parser.add_argument('-d', '--decrypt', help='Decrypt rather than encrypt',
                        action='store_true')
    parser.add_argument('-k', '--key', help='Hex key from stdin',
                        action='store_true')
    parser.add_argument('-n', '--noprompt',
                        help='Do not prompt for key or passphrase on stderr',
                        action='store_true')
    parser.add_argument('-o', '--out',
                        help='Output to file instead of stdout')
    parser.add_argument('-p', '--passphrase', help='Passphrase from stdin',
                        action='store_true')
    parser.add_argument('file', help="File to encrypt or decrypt")
    args = parser.parse_args()
    if args.key == args.passphrase:
        raise ValueError('Must specify one of -k or -p')
    assert args.bits % 8 == 0, 'bits in IV or salt must be a multiple of 8'
    bytes = args.bits // 8
    key = read_key(noprompt=args.noprompt)
    if args.passphrase:
        key_is_passphrase = True
    else:
        key_is_passphrase = False
        key = binascii.unhexlify(key)
        assert len(key) == 32, 'Key must be 64 hex digits, got {l}'.format(
            l=len(key) * 2)
    if args.out is None or args.out == '-':
        outfd = 1  # stdout
    else:
        outfile = open(args.out, 'wb')
        outfd = outfile.fileno()
    try:
        with open(args.file, 'rb') as fd:
            if args.decrypt:
                salt = fd.read(bytes)
                if key_is_passphrase:
                    assert len(salt) == bytes, "Can't read enough from encrypted file"
                    iv, key = iv_and_key_from_salt(salt, key)
                else:
                    iv = salt
                decrypt(iv, key, fd, outfd)
            else:
                encrypt(key, fd, outfd, bytes, key_is_passphrase=key_is_passphrase)
    except Exception:
        if outfd !=1:
            outfile.close()
            try:
                os.unlink(args.out)
            except Exception:
                pass
        raise  # Let the caller know what happened

    if outfd != 1:  # Not stdout
        outfile.close()

    exit(0)
