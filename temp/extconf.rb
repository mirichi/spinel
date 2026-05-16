# extconf.rb
require 'mkmf'
# Spinelのランタイム等へのインクルードパスを設定
$CFLAGS << " -I../lib"

have_header('sp_runtime.h')

# spinel_rt のリンク等も必要に応じて
create_makefile('myext')
