SRC_FILES := $(wildcard old/*.png)
DST_FILES := $(patsubst old/%.png,%.png,$(SRC_FILES))

all: $(DST_FILES)

%.png: old/%.png
	zopflipng $< --lossy_transparent --filters=01234mepb --iterations=10 $@