#!/usr/bin/env python3
"""Round-trip check of the OSR1 scheme. Always tests a throwaway keypair; also tests the real
key (public key from the contract + private key on disk) when the private key file exists."""
import base64, os, sys
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from osr1 import PUBLIC_KEY_B64, decrypt, encrypt, _RAW

sample = b"PK\x03\x04 sample zip bytes " + os.urandom(4096)

k = ec.generate_private_key(ec.SECP256R1())
blob = encrypt(sample, k.public_key().public_bytes(*_RAW))
assert blob[:4] == b"OSR1" and decrypt(blob, k) == sample
bad = bytearray(blob); bad[-1] ^= 1
try:
    decrypt(bytes(bad), k); sys.exit("tamper not detected")
except Exception:
    pass
print("throwaway keypair: ok")

p = os.path.expanduser(os.environ.get("REPORT_PRIVATE_KEY", "~/.openstrap-research/report-keys/report_private_key.pem"))
if os.path.exists(p):
    priv = serialization.load_pem_private_key(open(p, "rb").read(), None)
    assert priv.public_key().public_bytes(*_RAW) == base64.b64decode(PUBLIC_KEY_B64), "private key does not match contract public key"
    assert decrypt(encrypt(sample, base64.b64decode(PUBLIC_KEY_B64)), priv) == sample
    print("real key: ok")
else:
    print("real key: skipped (no private key at", p + ")")
