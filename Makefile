OPENSSL_VERSION=1.0.2c
OPENSSL=openssl-$(OPENSSL_VERSION)
OPENSSL_TGZ=$(OPENSSL).tar.gz
OPENSSL_URL=https://www.openssl.org/source/$(OPENSSL_TGZ)
OPENSSL_MD5=8c8d81a9ae7005276e486702edbcd4b6
OPENSSL_SHA1=6e4a5e91159eb32383296c7c83ac0e59b83a0a44
INSTALL_BIN_DIR=$(PREFIX)/usr/local/bin

ifeq ($(shell uname), Darwin)
CONFIG_OPENSSL=./Configure darwin64-x86_64-cc enable-ec_nistp_64_gcc_128 no-ssl2 no-ssl3 no-comp --openssldir=/usr/local/ssl/macos-x86_64
else
CONFIG_OPENSSL=./config
endif

gcmcrypt: gcmcrypt.cpp $(OPENSSL)/libcrypto.a
	g++ -o $@ gcmcrypt.cpp -I$(OPENSSL)/include -L$(OPENSSL) -lcrypto -ldl

$(OPENSSL)/libcrypto.a: $(OPENSSL)/Makefile
	cd $(OPENSSL) && $(CONFIG_OPENSSL) && make

$(OPENSSL)/Makefile: $(OPENSSL_TGZ)
	tar zxvf $(OPENSSL_TGZ)

$(OPENSSL_TGZ):
	curl -O $(OPENSSL_URL)
	test `openssl md5 < $(OPENSSL_TGZ)` = $(OPENSSL_MD5)
	test `openssl sha1 < $(OPENSSL_TGZ)` = $(OPENSSL_SHA1)

$(INSTALL_BIN_DIR):
	mkdir -p $@

install: $(INSTALL_BIN_DIR) gcmcrypt
	install gcmcrypt $(INSTALL_BIN_DIR)/gcmcrypt

clean:
	rm -rf openssl-*
	rm -rf *.o
	rm -rf gcmcrypt
