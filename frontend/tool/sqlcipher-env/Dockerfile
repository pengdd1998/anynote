# Test image: the Flutter toolchain plus a SQLCipher build that matches the
# one AnyNote ships on Android.
#
# Why it exists: the local database is SQLCipher-encrypted, but the stock
# `ghcr.io/cirruslabs/flutter` image only has plain SQLite, and the Ubuntu
# `libsqlcipher1` package is built WITHOUT FTS5. Running the test suite on
# either means it passes while the real app cannot open its database (that is
# how the 2026-11 upgrade regression escaped). This image compiles SQLCipher
# from the core sources with the exact compile flags of the Android build
# (sqlcipher-android, sqlcipher/src/main/jni/sqlcipher/Android.mk).
#
# Build (amd64, like every Flutter image on Apple Silicon):
#   docker build --platform linux/amd64 \
#     -t anynote-flutter-sqlcipher:4.10.0 -f frontend/tool/sqlcipher-env/Dockerfile \
#     frontend/tool/sqlcipher-env
#
# -DHAVE_STDINT_H=1 is the one desktop-only addition: it only makes the
# amalgamation include <stdint.h>, which the NDK build gets indirectly
# through the OpenSSL headers.
#
# `flutter test` picks the library up automatically through
# test/flutter_test_config.dart.
#
# libsodium is here for the rest of the suite, so the whole of it can run in
# this image: the crypto, sync and end-to-end tests load the real library
# (test/core/crypto/sodium_test_init.dart) and fail by the hundred without it.

FROM ghcr.io/cirruslabs/flutter:3.41.9

ARG SQLCIPHER_VERSION=4.10.0
# Verbatim from sqlcipher-android@v4.10.0 Android.mk (minus -DHAVE_USLEEP,
# which the autotools configure sets by itself).
ARG SQLCIPHER_CFLAGS="-DSQLITE_HAS_CODEC -DSQLCIPHER_CRYPTO_OPENSSL -DSQLITE_TEMP_STORE=2 \
-DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_COLUMN_METADATA -DSQLITE_ENABLE_FTS3_PARENTHESIS \
-DSQLITE_ENABLE_FTS4 -DSQLITE_ENABLE_FTS4_UNICODE61 -DSQLITE_ENABLE_FTS5 \
-DSQLITE_ENABLE_MEMORY_MANAGEMENT -DSQLITE_ENABLE_UNLOCK_NOTIFY -DSQLITE_ENABLE_RTREE \
-DSQLITE_SOUNDEX -DSQLITE_ENABLE_LOAD_EXTENSION -DSQLITE_ENABLE_STAT3 \
-DSQLITE_ENABLE_STAT4 -DSQLITE_ENABLE_JSON1 -DSQLITE_ENABLE_EXPLAIN_COMMENTS \
-DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1 -DSQLITE_MAX_VARIABLE_NUMBER=99999 \
-DSQLITE_DEFAULT_JOURNAL_SIZE_LIMIT=1048576 -DSQLITE_ENABLE_SESSION \
-DSQLITE_ENABLE_PREUPDATE_HOOK -DSQLITE_ENABLE_DBSTAT_VTAB \
-DSQLITE_EXTRA_INIT=sqlcipher_extra_init -DSQLITE_EXTRA_SHUTDOWN=sqlcipher_extra_shutdown"

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libssl-dev tcl git ca-certificates libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "v${SQLCIPHER_VERSION}" \
      https://github.com/sqlcipher/sqlcipher.git /tmp/sqlcipher \
    && cd /tmp/sqlcipher \
    && ./configure \
    && make sqlite3.c \
    && gcc -shared -fPIC -O2 -o /usr/local/lib/libsqlcipher.so.1 sqlite3.c \
         -I. -DHAVE_STDINT_H=1 ${SQLCIPHER_CFLAGS} -lcrypto \
    && ldconfig \
    && rm -rf /tmp/sqlcipher
