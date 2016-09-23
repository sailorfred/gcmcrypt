VERSION=1.0.5

OPENSSL_VERSION=1.0.2i
OPENSSL=openssl-$(OPENSSL_VERSION)
OPENSSL_TGZ=$(OPENSSL).tar.gz
OPENSSL_URL=https://www.openssl.org/source/$(OPENSSL_TGZ)
OPENSSL_SHA256=9287487d11c9545b6efb287cdb70535d4e9b284dd10d51441d9b9963d000de6f
OPENSSL_SHA1=25a92574ebad029dcf2fa26c02e10400a0882111
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
