OPENSSL_VERSION=1.0.2a
OPENSSL=openssl-$(OPENSSL_VERSION)
OPENSSL_TGZ=$(OPENSSL).tar.gz
OPENSSL_URL=https://www.openssl.org/source/$(OPENSSL_TGZ)

gcmcrypt: gcmcrypt.cpp $(OPENSSL)/libcrypto.a
	g++ -o $@ gcmcrypt.cpp -I$(OPENSSL)/include -L$(OPENSSL) -lcrypto -ldl

$(OPENSSL)/libcrypto.a: $(OPENSSL)
	cd $(OPENSSL) && ./config && make

$(OPENSSL): $(OPENSSL_TGZ)
	tar zxvf $(OPENSSL_TGZ)

$(OPENSSL_TGZ):
	wget $(OPENSSL_URL)
	md5sum -c $(OPENSSL_TGZ).md5
	sha1sum -c $(OPENSSL_TGZ).sha1

clean:
	rm -rf $(OPENSSL)
	rm -rf *.o
	rm -rf gcmcrypt
