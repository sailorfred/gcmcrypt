VERSION=1.0.6

OPENSSL_VERSION=1.0.2k
OPENSSL=openssl-$(OPENSSL_VERSION)
OPENSSL_TGZ=$(OPENSSL).tar.gz
OPENSSL_URL=https://www.openssl.org/source/$(OPENSSL_TGZ)
OPENSSL_SHA256=6b3977c61f2aedf0f96367dcfb5c6e578cf37e7b8d913b4ecb6643c3cb88d8c0
OPENSSL_SHA1=5f26a624479c51847ebd2f22bb9f84b3b44dcb44
INSTALL_BIN_DIR=$(PREFIX)/usr/local/bin

ifeq ($(shell uname), Darwin)
CONFIG_OPENSSL=./Configure darwin64-x86_64-cc enable-ec_nistp_64_gcc_128 no-ssl2 no-ssl3 no-comp --openssldir=/usr/local/ssl/macos-x86_64
else
CONFIG_OPENSSL=./config
endif

gcmcrypt: gcmcrypt.cpp $(OPENSSL)/libcrypto.a
	g++ -o $@ gcmcrypt.cpp -DVERSION='"'$(VERSION)'"' -I$(OPENSSL)/include -L$(OPENSSL) -lcrypto -ldl

$(OPENSSL)/libcrypto.a: $(OPENSSL)/Makefile
	cd $(OPENSSL) && $(CONFIG_OPENSSL) && make

$(OPENSSL)/Makefile: $(OPENSSL_TGZ)
	tar zxvf $(OPENSSL_TGZ)

$(OPENSSL_TGZ):
	curl -O $(OPENSSL_URL) || (rm -f $@ ; false)
	(test `openssl sha256 < $(OPENSSL_TGZ) | sed -e 's/^.*= //'` = $(OPENSSL_SHA256) ) || (rm -f $@ ; false)
	(test `openssl sha1 < $(OPENSSL_TGZ)| sed -e 's/^.*= //'` = $(OPENSSL_SHA1) ) || (rm -f $@ ; false)

$(INSTALL_BIN_DIR):
	mkdir -p $@

install: $(INSTALL_BIN_DIR) gcmcrypt
	install gcmcrypt $(INSTALL_BIN_DIR)/gcmcrypt

clean:
	rm -rf openssl-*
	rm -rf *.o
	rm -rf gcmcrypt
