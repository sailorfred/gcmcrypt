#include <openssl/aes.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <algorithm>
#include <string>
#include <sstream>
#include <vector>
#include <iostream>
#include <getopt.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/fcntl.h>
#include <unistd.h>
#include <ctype.h>

using std::cerr;
using std::cout;
using std::endl;

bool opt_decrypt = false;
bool opt_key = false;
bool opt_noprompt = false;
char *opt_out = 0;
char *infile = 0;

#define KEY_SIZE 32

void
parse_args( int argc, char **argv )
{
  const struct option longopts[] = {
    { "decrypt",  no_argument,        0, 'd'},
    { "key",      no_argument,        0, 'k'},
    { "noprompt", no_argument,        0, 'n'},
    { "out",      required_argument,  0, 'o'},
    {0,0,0,0},
  };

  int c = 0;

  while ( c != -1 ) {
    c = getopt_long( argc, argv, "dkno:", longopts, 0 );
    switch ( c ) {
    case 'd':
      opt_decrypt = true;
      break;
    case 'k':
      opt_key = true;
      break;
    case 'n':
      opt_noprompt = true;
      break;
    case 'o':
      opt_out = optarg;
      break;
    case -1:
      break;
    default:
      cerr << "Unknown option " << char(c) << " " << c << endl;
      exit( 1 );
    }
  }
  if ( ! opt_key ) {
    cerr << "Key or passphrase required" << endl;
    exit( 1 );
  }
  if ( optind == ( argc - 1 ) ) {
    infile = argv[optind];
  } else {
    cerr << "Missing file name arg" << endl;
    exit( 1 );
  }
}

unsigned char
hex_value( char c )
{
  switch ( c ) {
  case '0':
    return 0;
  case '1':
    return 1;
  case '2':
    return 2;
  case '3':
    return 3;
  case '4':
    return 4;
  case '5':
    return 5;
  case '6':
    return 6;
  case '7':
    return 7;
  case '8':
    return 8;
  case '9':
    return 9;
  case 'a':
  case 'A':
    return 10;
  case 'b':
  case 'B':
    return 11;
  case 'c':
  case 'C':
    return 12;
  case 'd':
  case 'D':
    return 13;
  case 'e':
  case 'E':
    return 14;
  case 'f':
  case 'F':
    return 15;
  default:
    cerr << "Illegal hex char: " << c << endl;
    exit( 1 );
  }
}

void
read_key( unsigned char *buf )
{
  char hex_buf[2];

  if ( ! opt_noprompt ) {
    cerr << "Enter key or passphrase, ending with EOF: ";
  }
  for ( int i = 0 ; i < KEY_SIZE ; ++i ) {
    if ( read( 0, hex_buf, sizeof( hex_buf ) ) != sizeof( hex_buf ) ) {
      cerr << "Failed to read full key" << endl;
      exit( 1 );
    }
    buf[i] = hex_value( hex_buf[0] ) << 4 | hex_value( hex_buf[1] );
  }
  // Check for extra junk
  while ( read( 0, hex_buf, 1 ) > 0 ) {
    if ( ! isspace( hex_buf[0] ) ) {
      cerr << "Unexpected non-whitespace trailing key" << endl;
      exit( 1 );
    }
  }
}

void
gcm_decrypt( int fd, size_t file_len, unsigned char *key_buf )
{
  unsigned char iv[12];
  unsigned char tag[AES_BLOCK_SIZE];
  unsigned char in_buf[65536];
  unsigned char out_buf[65536];
  EVP_CIPHER_CTX ctx;
  size_t bytes_read;
  int bytes_decrypted;
  size_t to_read = file_len - (AES_BLOCK_SIZE + 12);
  int out_fd = 1;  // stdout, unless --out specified

  if ( file_len < (AES_BLOCK_SIZE + 12) ) {
    cerr << "File not long enough to be encrypted" << endl;
    exit( 1 );
  }
  // Get auth tag
  if ( lseek( fd, -AES_BLOCK_SIZE, SEEK_END ) == -1 ) {
    cerr << "Failed to seek to auth tag" << endl;
    exit( 1 );
  }
  if ( read( fd, tag, AES_BLOCK_SIZE ) != AES_BLOCK_SIZE ) {
    cerr << "Failed to read auth tag" << endl;
    exit( 1 );
  }
  // Get IV
  if ( lseek( fd, 0, SEEK_SET ) != 0 ) {
    cerr << "Failed to seek to start of file" << endl;
    exit( 1 );
  }
  if ( read( fd, iv, 12 ) != 12 ) {
    cerr << "Failed to read IV" << endl;
    exit( 1 );
  }

  if ( opt_out ) {
    if ( ( out_fd = open( opt_out, O_CREAT | O_WRONLY, 0644 ) ) == -1 ) {
      cerr << "Couldn't create output file" << endl;
      exit( 1 );
    }
  }
  EVP_CIPHER_CTX_init( &ctx );
  if ( EVP_DecryptInit_ex( &ctx, EVP_aes_256_gcm(), 0, key_buf, iv ) != 1 ) {
    cerr << "Failed to initialize decryptor" << endl;
    exit( 1 );
  }
  while ( to_read > 0 ) {
    bytes_read = read( fd, in_buf, std::min( 65536, int( to_read ) ) );
    if ( bytes_read < 1 ) {
      cerr << "Couldn't read file" << endl;
      exit( 1 );
    }
    to_read -= bytes_read;
    if ( EVP_DecryptUpdate( &ctx, out_buf, &bytes_decrypted, in_buf, bytes_read ) != 1 ) {
      cerr << "Failed to decrypt" << endl;
      exit( 1 );
    }
    if ( write( out_fd, out_buf, bytes_decrypted ) != bytes_decrypted ) {
      cerr << "Couldn't write decrypted bytes" << endl;
      exit( 1 );
    }
  }
  // Check auth tag
  if ( EVP_CIPHER_CTX_ctrl( &ctx, EVP_CTRL_GCM_SET_TAG, AES_BLOCK_SIZE, tag ) != 1 ) {
    cerr << "Failed to initialize set auth tag" << endl;
    exit( 1 );
  }
  if ( EVP_DecryptFinal( &ctx, out_buf, &bytes_decrypted ) != 1 ) {
    cerr << "Failed to finalize decryptor" << endl;
    exit( 1 );
  }
  if ( bytes_decrypted != 0 ) {
    cerr << "Decrypt finalization returned extra stuff" << endl;
    exit( 1 );
  }
  if ( out_fd != 1 ) {
    if ( close( out_fd ) != 0 ) {
      cerr << "Failed to close --out file" << endl;
      exit( 1 );
    }
  }
}

void gcm_encrypt( int fd, size_t file_len, unsigned char *key_buf )
{
  unsigned char iv[12];
  unsigned char tag[AES_BLOCK_SIZE];
  unsigned char in_buf[65536];
  unsigned char out_buf[65536];
  EVP_CIPHER_CTX ctx;
  size_t bytes_read;
  int bytes_encrypted;
  int out_fd = 1;

  if ( opt_out ) {
    if ( ( out_fd = open( opt_out, O_CREAT | O_WRONLY, 0644 ) ) == -1 ) {
      cerr << "Couldn't create output file" << endl;
      exit( 1 );
    }
  }
  EVP_CIPHER_CTX_init( &ctx );
  RAND_bytes( iv, sizeof(iv) );
  if ( write( out_fd, iv, sizeof(iv) ) != sizeof(iv) ) {
    cerr << "Failed to write IV to stdout" << endl;
    exit( 1 );
  }
  if ( lseek( fd, 0, SEEK_SET ) != 0 ) {
    cerr << "Failed to seek to start of file" << endl;
    exit( 1 );
  }
  if ( EVP_EncryptInit_ex( &ctx, EVP_aes_256_gcm(), 0, key_buf, iv ) != 1 ) {
    cerr << "Failed to initialize encryptor" << endl;
    exit( 1 );
  }
  while ( ( bytes_read = read( fd, in_buf, 65536 ) ) > 0 ) {
    if ( EVP_EncryptUpdate( &ctx, out_buf, &bytes_encrypted, in_buf, bytes_read ) != 1 ) {
      cerr << "Failed to encrypt" << endl;
      exit( 1 );
    }
    if ( write( out_fd, out_buf, bytes_encrypted ) != bytes_encrypted ) {
      cerr << "Failed to write encrypted data" << endl;
      exit( 1 );
    }
  }
  if ( EVP_EncryptFinal_ex( &ctx, out_buf, &bytes_encrypted ) != 1 ) {
    cerr << "Failed to finalize encryption" << endl;
    exit( 1 );
  }
  if ( bytes_encrypted != 0 ) {
    cerr << "Finalized unexpected " << bytes_encrypted << " bytes output" << endl;
    exit( 1 );
  }
  if ( EVP_CIPHER_CTX_ctrl( &ctx, EVP_CTRL_GCM_GET_TAG, AES_BLOCK_SIZE, tag ) != 1 ) {
    cerr << "Failed to get auth tag" << endl;
    exit( 1 );
  }
  if ( write( out_fd, tag, AES_BLOCK_SIZE ) != AES_BLOCK_SIZE ) {
    cerr << "Failed to write GCM tag" << endl;
    exit( 1 );
  }
  if ( out_fd != 1 ) {
    if ( close( out_fd ) != 0 ) {
      cerr << "Failed to close --out file" << endl;
      exit( 1 );
    }
  }
}

int
main(int argc, char **argv)
{
  unsigned char key_buf[KEY_SIZE];

  parse_args( argc, argv );

  // Init PRNG
  int read_bytes = RAND_load_file( "/dev/urandom", 1024 );

  if ( read_bytes != 1024 ) {
    cerr << "Could not seed PRNG from /dev/urandom (" << read_bytes << "/1024 read" << endl;
    exit( 1 );
  }
  // Init ciphers
  OpenSSL_add_all_ciphers();

  // Open input file
  int fd = open( infile, O_RDONLY );
  if ( fd == -1 ) {
    cerr << "Couldn't open " << infile << endl;
    exit( 1 );
  }
  // Check its size
  off_t file_len = lseek( fd, 0, SEEK_END );
  if ( file_len == (off_t) -1 ) {
    cerr << "Couldn't seek to end of file" << endl;
    exit( 1 );
  }
  if ( opt_key ) { // Read key from stdin
    read_key( key_buf );
  }
  if ( opt_decrypt ) {
    gcm_decrypt( fd, file_len, key_buf );
  } else {
    gcm_encrypt( fd, file_len, key_buf );
  }
  exit( 0 );
}
