OPENSSL_VERSION=1.0.2d
OPENSSL=openssl-$(OPENSSL_VERSION)
OPENSSL_TGZ=$(OPENSSL).tar.gz
OPENSSL_URL=https://www.openssl.org/source/$(OPENSSL_TGZ)
OPENSSL_MD5=38dd619b2e77cbac69b99f52a053d25a
OPENSSL_SHA1=d01d17b44663e8ffa6a33a5a30053779d9593c3d
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
	curl -O $(OPENSSL_URL) || (rm -f $@ ; false)
	(test `openssl md5 < $(OPENSSL_TGZ) | sed -e 's/^.*= //'` = $(OPENSSL_MD5) ) || (rm -f $@ ; false)
	(test `openssl sha1 < $(OPENSSL_TGZ)| sed -e 's/^.*= //'` = $(OPENSSL_SHA1) ) || (rm -f $@ ; false)

$(INSTALL_BIN_DIR):
	mkdir -p $@

install: $(INSTALL_BIN_DIR) gcmcrypt
	install gcmcrypt $(INSTALL_BIN_DIR)/gcmcrypt

clean:
	rm -rf openssl-*
	rm -rf *.o
	rm -rf gcmcrypt
