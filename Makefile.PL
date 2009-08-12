use inc::Module::Install;

name ('Data-Plist');
author ('Alex Vandiver <alexmv@mit.edu>');
version_from ('lib/Data/Plist.pm');
abstract_from('lib/Data/Plist.pm');
license('perl');

requires('Class::ISA');
requires('Class::Accessor');
requires('DateTime');
requires('Encode');
requires('MIME::Base64');
requires('Scalar::Util');
requires('UNIVERSAL::isa');
requires('UNIVERSAL::require');
requires('URI');
requires('XML::Writer');

&WriteAll;
