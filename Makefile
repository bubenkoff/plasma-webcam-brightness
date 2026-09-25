PREFIX ?= /usr
DESTDIR ?=
BINDIR = $(PREFIX)/bin
# user units live in share/ for a ~/.local install, lib/ for a system install
ifeq ($(PREFIX),/usr)
UNITDIR = $(PREFIX)/lib/systemd/user
else
UNITDIR = $(PREFIX)/share/systemd/user
endif

all: plasma-webcam-brightness.service

plasma-webcam-brightness.service: plasma-webcam-brightness.service.in
	sed 's|@BINDIR@|$(BINDIR)|' $< > $@

install: plasma-webcam-brightness.service
	install -Dm755 plasma-webcam-brightness $(DESTDIR)$(BINDIR)/plasma-webcam-brightness
	install -Dm644 plasma-webcam-brightness.service $(DESTDIR)$(UNITDIR)/plasma-webcam-brightness.service

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/plasma-webcam-brightness $(DESTDIR)$(UNITDIR)/plasma-webcam-brightness.service

clean:
	rm -f plasma-webcam-brightness.service

.PHONY: all install uninstall clean
