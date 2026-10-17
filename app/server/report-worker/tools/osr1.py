"""OSR1 report blob: ECDH P-256 + HKDF-SHA256 + AES-256-GCM. Needs `pip install cryptography`."""
import os
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

PUBLIC_KEY_B64 = "BPMdcMa2jzNju8JAdSFLFwRuhvEDcaPPUmFbamtbKR2kb7SEml4HfuXf1nRg/SKZNFrG/TBbjx9Jai+/BLHbmhc="
INFO = b"openstrap-report-v1"
_RAW = serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint


def _key(shared: bytes, eph_pub: bytes) -> bytes:
    return HKDF(hashes.SHA256(), 32, salt=eph_pub, info=INFO).derive(shared)


def encrypt(plain: bytes, recipient_pub: bytes) -> bytes:
    eph = ec.generate_private_key(ec.SECP256R1())
    eph_pub = eph.public_key().public_bytes(*_RAW)
    peer = ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), recipient_pub)
    nonce = os.urandom(12)
    return b"OSR1" + eph_pub + nonce + AESGCM(_key(eph.exchange(ec.ECDH(), peer), eph_pub)).encrypt(nonce, plain, None)


def decrypt(blob: bytes, private_key) -> bytes:
    if blob[:4] != b"OSR1" or len(blob) < 4 + 65 + 12 + 16:
        raise ValueError("not an OSR1 blob")
    eph_pub, nonce, ct = blob[4:69], blob[69:81], blob[81:]
    peer = ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), eph_pub)
    return AESGCM(_key(private_key.exchange(ec.ECDH(), peer), eph_pub)).decrypt(nonce, ct, None)
