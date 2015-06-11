OPENSSL_VERSION=1.0.2b
OPENSSL=openssl-$(OPENSSL_VERSION)
OPENSSL_TGZ=$(OPENSSL).tar.gz
OPENSSL_URL=https://www.openssl.org/source/$(OPENSSL_TGZ)

INSTALL_BIN_DIR=$(PREFIX)/usr/local/bin

gcmcrypt: gcmcrypt.cpp $(OPENSSL)/libcrypto.a
	g++ -o $@ gcmcrypt.cpp -I$(OPENSSL)/include -L$(OPENSSL) -lcrypto -ldl

$(OPENSSL)/libcrypto.a: $(OPENSSL)/Makefile
	cd $(OPENSSL) && ./config && make

$(OPENSSL)/Makefile: $(OPENSSL_TGZ)
	tar zxvf $(OPENSSL_TGZ)

$(OPENSSL_TGZ):
	wget $(OPENSSL_URL)
	md5sum -c $(OPENSSL_TGZ).md5
	sha1sum -c $(OPENSSL_TGZ).sha1

$(INSTALL_BIN_DIR):
	mkdir -p $@

install: $(INSTALL_BIN_DIR) gcmcrypt
	install gcmcrypt $(INSTALL_BIN_DIR)/gcmcrypt

clean:
	rm -rf $(OPENSSL)
	rm -rf *.o
	rm -rf gcmcrypt
